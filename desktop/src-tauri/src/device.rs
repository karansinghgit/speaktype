//! What this computer can run, and which model to recommend for it.

use serde::Serialize;
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};

use crate::models::{CATALOG, ModelInfo};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceInfo {
    chip: String,
    ram_gb: u32,
    cores: usize,
    /// Whether whisper.cpp runs on a GPU in this build.
    gpu: bool,
    /// A short line like "Apple M3 Pro · 18 GB · Metal".
    summary: String,
    /// 0..1 estimate of how fast this machine runs models.
    performance_tier: f64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Recommendation {
    model_id: &'static str,
    reason: String,
}

/// Reads the CPU and memory. Takes a moment, so callers cache the result.
pub fn detect() -> DeviceInfo {
    let system = System::new_with_specifics(
        RefreshKind::nothing()
            .with_cpu(CpuRefreshKind::nothing())
            .with_memory(MemoryRefreshKind::nothing().with_ram()),
    );
    let chip = system
        .cpus()
        .first()
        .map(|cpu| cpu.brand().trim().to_string())
        .filter(|brand| !brand.is_empty())
        .unwrap_or_else(|| "this computer".into());
    let ram_gb = (system.total_memory() as f64 / 1024f64.powi(3)).round() as u32;
    let cores = System::physical_core_count().unwrap_or(4);
    let backend = gpu_backend();
    let summary = match backend {
        Some(backend) => format!("{chip} · {ram_gb} GB · {backend}"),
        None => format!("{chip} · {ram_gb} GB"),
    };
    DeviceInfo {
        performance_tier: performance_tier(&chip, cores, backend.is_some()),
        chip,
        ram_gb,
        cores,
        gpu: backend.is_some(),
        summary,
    }
}

fn gpu_backend() -> Option<&'static str> {
    if cfg!(target_os = "macos") {
        Some("Metal")
    } else if cfg!(feature = "cuda") {
        Some("CUDA")
    } else if cfg!(feature = "vulkan") {
        Some("Vulkan")
    } else {
        None
    }
}

/// Same shape as the macOS app's estimate: newer Apple Silicon scores higher,
/// and more cores add a little.
fn performance_tier(chip: &str, cores: usize, gpu: bool) -> f64 {
    let base = match apple_silicon_generation(chip) {
        Some(generation) => (0.6 + (generation as f64 - 1.0) * 0.12).min(1.0),
        None if gpu => 0.6,
        None => 0.5,
    };
    let core_bonus = ((cores as f64 - 4.0) * 0.02).clamp(0.0, 0.15);
    (base + core_bonus).min(1.0)
}

fn apple_silicon_generation(chip: &str) -> Option<u32> {
    let rest = chip.strip_prefix("Apple M")?;
    let digits = rest
        .find(|c: char| !c.is_ascii_digit())
        .unwrap_or(rest.len());
    rest[..digits].parse().ok()
}

/// Picks the model that best balances speed and accuracy for dictation on this machine.
pub fn recommend(device: &DeviceInfo, language: &str) -> Recommendation {
    let candidates: Vec<&ModelInfo> = crate::models::available()
        .filter(|m| m.supports_language(language))
        .collect();
    let fits: Vec<&ModelInfo> = candidates
        .iter()
        .copied()
        .filter(|m| m.min_ram_gb <= device.ram_gb)
        .collect();
    let pool = if fits.is_empty() { candidates } else { fits };

    // Multilingual Whisper models support every language, so the pool is only
    // empty if the catalog changes; fall back to its first entry then.
    let best = pool
        .into_iter()
        .max_by(|a, b| score(a, device).total_cmp(&score(b, device)))
        .unwrap_or(&CATALOG[0]);

    let reason = format!(
        "Fast and accurate enough for live dictation, and {} on your {}.",
        if best.size_mb < 600 {
            "loads quickly"
        } else {
            "runs comfortably"
        },
        device.chip
    );
    Recommendation {
        model_id: best.id,
        reason,
    }
}

fn score(model: &ModelInfo, device: &DeviceInfo) -> f64 {
    const SPEED_WEIGHT: f64 = 0.45;
    const ACCURACY_WEIGHT: f64 = 0.55;
    let mut score = SPEED_WEIGHT * (model.speed / 10.0) * (0.5 + 0.5 * device.performance_tier)
        + ACCURACY_WEIGHT * (model.accuracy / 10.0)
        + ((device.ram_gb.saturating_sub(model.min_ram_gb)) as f64 * 0.01).min(0.1);
    // Large models are slow without a GPU.
    if !device.gpu && model.size_mb > 1000 {
        score -= 0.15;
    }
    score
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device(chip: &str, ram_gb: u32, gpu: bool) -> DeviceInfo {
        DeviceInfo {
            chip: chip.into(),
            ram_gb,
            cores: 8,
            gpu,
            summary: String::new(),
            performance_tier: performance_tier(chip, 8, gpu),
        }
    }

    #[test]
    fn reads_apple_silicon_generation() {
        assert_eq!(apple_silicon_generation("Apple M3 Pro"), Some(3));
        assert_eq!(apple_silicon_generation("Apple M10"), Some(10));
        assert_eq!(apple_silicon_generation("Intel(R) Core(TM) i7"), None);
        assert_eq!(apple_silicon_generation("Apple M"), None);
        assert_eq!(apple_silicon_generation("Apple M99999999999 Ultra"), None);
    }

    #[test]
    fn performance_tier_stays_in_range() {
        for (chip, cores, gpu) in [
            ("Apple M1", 8, true),
            ("Apple M9 Max", 64, true),
            ("Apple M0", 0, true),
            ("Intel Celeron", 1, false),
            ("AMD Ryzen 9", 32, true),
        ] {
            let tier = performance_tier(chip, cores, gpu);
            assert!((0.0..=1.0).contains(&tier), "{chip}: {tier}");
        }
        assert!(performance_tier("Apple M4", 10, true) > performance_tier("Apple M1", 10, true));
    }

    #[test]
    fn recommends_parakeet_when_the_language_allows_it() {
        let rec = recommend(&device("Apple M3", 16, true), "auto");
        assert_eq!(rec.model_id, "parakeet-tdt-v3");
        let rec = recommend(&device("AMD Ryzen 7", 16, false), "de");
        assert_eq!(rec.model_id, "parakeet-tdt-v3");
    }

    #[test]
    fn recommends_whisper_for_languages_parakeet_lacks() {
        let rec = recommend(&device("Apple M3", 16, true), "hi");
        assert_eq!(rec.model_id, "large-v3-turbo-q5");
    }

    #[test]
    fn respects_ram_and_language() {
        let rec = recommend(&device("Intel Celeron", 2, false), "auto");
        assert!(crate::models::find(rec.model_id).unwrap().min_ram_gb <= 2);
        let rec = recommend(&device("Intel Celeron", 2, false), "ja");
        assert!(
            crate::models::find(rec.model_id)
                .unwrap()
                .supports_language("ja")
        );
    }
}
