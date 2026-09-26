//! Speech model catalog and downloads.
//!
//! - Whisper: GGML files that whisper.cpp publishes on Hugging Face. On macOS
//!   each also gets a CoreML encoder so it can run on the Neural Engine.
//! - Parakeet: int8 ONNX exports of NVIDIA's Parakeet TDT, one folder of files.

use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::{
        Arc, Mutex, MutexGuard,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use futures_util::StreamExt;
use serde::Serialize;
use sysinfo::{DiskRefreshKind, Disks};
use tokio::io::AsyncWriteExt;

use crate::{LockExt, platform};

const WHISPER_BASE_URL: &str = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

/// Files in a Parakeet model folder, as `ParakeetModel::load` expects them.
const PARAKEET_FILES: &[&str] = &[
    "nemo128.onnx",
    "vocab.txt",
    "decoder_joint-model.int8.onnx",
    "encoder-model.int8.onnx",
];

/// Languages Parakeet TDT v3 transcribes.
const PARAKEET_V3_LANGUAGES: &[&str] = &[
    "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "it", "lt", "lv", "mt",
    "nl", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "uk",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineKind {
    Whisper,
    Parakeet,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelInfo {
    pub id: &'static str,
    pub name: &'static str,
    pub engine: EngineKind,
    /// Whisper: the GGML file name. Parakeet: the folder name.
    #[serde(skip)]
    pub file: &'static str,
    /// Hugging Face repo for Parakeet files.
    #[serde(skip)]
    pub repo: &'static str,
    /// CoreML encoder for the Neural Engine, as published next to the GGML file.
    #[serde(skip)]
    pub coreml_encoder: Option<&'static str>,
    /// Download size of the model itself, without the Neural Engine companion.
    pub size_mb: u32,
    /// Extra download for Neural Engine acceleration, where available.
    pub accelerator_mb: u32,
    pub english_only: bool,
    /// Languages the model can transcribe, or `None` for every Whisper language.
    pub languages: Option<&'static [&'static str]>,
    pub description: &'static str,
    /// Relative scores out of 10, shown as bars in AI Models.
    pub speed: f64,
    pub accuracy: f64,
    pub min_ram_gb: u32,
}

/// Neural Engine files up to this size download with the model. Larger ones
/// (1.1 GB for Turbo) are an optional extra the user adds from AI Models.
const AUTO_ACCELERATOR_MB: u32 = 200;

impl ModelInfo {
    pub fn supports_language(&self, language: &str) -> bool {
        language == "auto"
            || self
                .languages
                .is_none_or(|languages| languages.contains(&language))
    }
}

const WHISPER: ModelInfo = ModelInfo {
    id: "",
    name: "",
    engine: EngineKind::Whisper,
    file: "",
    repo: "",
    coreml_encoder: None,
    size_mb: 0,
    accelerator_mb: 0,
    english_only: false,
    languages: None,
    description: "",
    speed: 0.0,
    accuracy: 0.0,
    min_ram_gb: 0,
};

pub const CATALOG: &[ModelInfo] = &[
    ModelInfo {
        id: "parakeet-tdt-v3",
        name: "Parakeet v3",
        engine: EngineKind::Parakeet,
        file: "parakeet-tdt-0.6b-v3-int8",
        repo: "istupakov/parakeet-tdt-0.6b-v3-onnx",
        size_mb: 640,
        languages: Some(PARAKEET_V3_LANGUAGES),
        description: "Fastest model, with punctuation. English and 24 European languages.",
        speed: 9.7,
        accuracy: 9.2,
        min_ram_gb: 4,
        ..WHISPER
    },
    ModelInfo {
        id: "parakeet-tdt-v2",
        name: "Parakeet v2 (English)",
        engine: EngineKind::Parakeet,
        file: "parakeet-tdt-0.6b-v2-int8",
        repo: "istupakov/parakeet-tdt-0.6b-v2-onnx",
        size_mb: 631,
        english_only: true,
        languages: Some(&["en"]),
        description: "Very fast and accurate for English.",
        speed: 9.8,
        accuracy: 9.1,
        min_ram_gb: 4,
        ..WHISPER
    },
    ModelInfo {
        id: "large-v3-turbo-q5",
        name: "Whisper Large v3 Turbo (compressed)",
        file: "ggml-large-v3-turbo-q5_0.bin",
        coreml_encoder: Some("ggml-large-v3-turbo-encoder.mlmodelc.zip"),
        size_mb: 547,
        accelerator_mb: 1119,
        description: "Near-flagship accuracy at a third of the size. Great for dictation in any language.",
        speed: 7.5,
        accuracy: 9.4,
        min_ram_gb: 6,
        ..WHISPER
    },
    ModelInfo {
        id: "large-v3-turbo",
        name: "Whisper Large v3 Turbo",
        file: "ggml-large-v3-turbo.bin",
        coreml_encoder: Some("ggml-large-v3-turbo-encoder.mlmodelc.zip"),
        size_mb: 1624,
        accelerator_mb: 1119,
        description: "The most accurate Whisper model. Best on machines with a fast GPU.",
        speed: 7.0,
        accuracy: 9.5,
        min_ram_gb: 8,
        ..WHISPER
    },
    ModelInfo {
        id: "small-en",
        name: "Whisper Small (English)",
        file: "ggml-small.en.bin",
        coreml_encoder: Some("ggml-small.en-encoder.mlmodelc.zip"),
        size_mb: 466,
        accelerator_mb: 155,
        english_only: true,
        languages: Some(&["en"]),
        description: "Good balance of speed and accuracy for English.",
        speed: 8.0,
        accuracy: 8.5,
        min_ram_gb: 4,
        ..WHISPER
    },
    ModelInfo {
        id: "base-en",
        name: "Whisper Base (English)",
        file: "ggml-base.en.bin",
        coreml_encoder: Some("ggml-base.en-encoder.mlmodelc.zip"),
        size_mb: 142,
        accelerator_mb: 36,
        english_only: true,
        languages: Some(&["en"]),
        description: "Fast on any machine. Fine for short English dictation.",
        speed: 9.0,
        accuracy: 7.5,
        min_ram_gb: 2,
        ..WHISPER
    },
    ModelInfo {
        id: "base",
        name: "Whisper Base",
        file: "ggml-base.bin",
        coreml_encoder: Some("ggml-base-encoder.mlmodelc.zip"),
        size_mb: 142,
        accelerator_mb: 36,
        description: "Small and quick to download. A good way to get started in any language.",
        speed: 9.0,
        accuracy: 7.3,
        min_ram_gb: 2,
        ..WHISPER
    },
    ModelInfo {
        id: "tiny",
        name: "Whisper Tiny",
        file: "ggml-tiny.bin",
        coreml_encoder: Some("ggml-tiny-encoder.mlmodelc.zip"),
        size_mb: 75,
        accelerator_mb: 14,
        description: "Fastest Whisper model and least accurate. Useful for testing.",
        speed: 9.5,
        accuracy: 6.0,
        min_ram_gb: 2,
        ..WHISPER
    },
];

/// Whether this build includes Parakeet. Intel Macs don't (see build.rs).
pub const PARAKEET: bool = cfg!(parakeet);

impl ModelInfo {
    /// Whether this build can run the model.
    pub fn is_available(&self) -> bool {
        self.engine != EngineKind::Parakeet || PARAKEET
    }
}

/// The models this build can run, in catalog order.
pub fn available() -> impl Iterator<Item = &'static ModelInfo> {
    CATALOG.iter().filter(|m| m.is_available())
}

/// A model this build can run, by id.
pub fn find(id: &str) -> Option<&'static ModelInfo> {
    available().find(|m| m.id == id)
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelStatus {
    #[serde(flatten)]
    pub info: ModelInfo,
    /// Ready to transcribe.
    pub downloaded: bool,
    pub downloading: bool,
    /// Whether Neural Engine acceleration applies on this computer, and is installed.
    pub accelerator: Accelerator,
    /// What a fresh download fetches on this computer, including any Neural Engine files.
    pub download_mb: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Accelerator {
    /// Not offered for this model on this OS.
    None,
    Missing,
    Installed,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DownloadProgress {
    pub id: String,
    pub downloaded: u64,
    pub total: u64,
}

/// One file to fetch for a model.
struct Asset {
    url: String,
    /// Where the finished file (or, for zips, the extracted folder) ends up.
    dest: PathBuf,
    /// Zipped folders are extracted next to `dest` and the zip is removed.
    zipped: bool,
}

impl Asset {
    /// Where the download is written until it's complete. Named for the model, so
    /// models sharing an asset (the Turbo encoder) can download at the same time
    /// without writing to the same file.
    fn part(&self, model_id: &str) -> PathBuf {
        let ext = if self.zipped { ".zip.part" } else { ".part" };
        with_suffix(&self.dest, &format!(".{model_id}{ext}"))
    }

    /// Where a zip is extracted before the result is moved into place.
    fn staging(&self, model_id: &str) -> PathBuf {
        with_suffix(&self.dest, &format!(".{model_id}.extracting"))
    }
}

/// Gives up on a connection that stops sending data, instead of showing the
/// download as in progress forever.
const READ_TIMEOUT: Duration = Duration::from_secs(30);
const CONNECT_TIMEOUT: Duration = Duration::from_secs(15);
/// How often download progress is reported.
const PROGRESS_INTERVAL: Duration = Duration::from_millis(200);

pub struct ModelStore {
    dir: PathBuf,
    /// Downloads in progress, by model id, with their cancel flags.
    active: Mutex<HashMap<String, Arc<AtomicBool>>>,
}

impl ModelStore {
    pub fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            active: Mutex::new(HashMap::new()),
        }
    }

    /// Nothing panics while holding this lock and the map is valid after every
    /// operation, so a poisoned lock is still safe to use.
    fn active(&self) -> MutexGuard<'_, HashMap<String, Arc<AtomicBool>>> {
        self.active.lock_unpoisoned()
    }

    /// The Whisper file or Parakeet folder the engine loads.
    pub fn path(&self, model: &ModelInfo) -> PathBuf {
        self.dir.join(model.file)
    }

    fn coreml_path(&self, model: &ModelInfo) -> Option<PathBuf> {
        let zip = model.coreml_encoder.filter(|_| platform::NEURAL_ENGINE)?;
        Some(self.dir.join(zip.trim_end_matches(".zip")))
    }

    /// Files for a model on this OS. The Neural Engine companion is included when
    /// `with_accelerator` is true.
    fn assets(&self, model: &ModelInfo, with_accelerator: bool) -> Vec<Asset> {
        match model.engine {
            EngineKind::Whisper => {
                let mut assets = vec![Asset {
                    url: format!("{WHISPER_BASE_URL}/{}", model.file),
                    dest: self.path(model),
                    zipped: false,
                }];
                if let (true, Some(zip), Some(dest)) = (
                    with_accelerator,
                    model.coreml_encoder,
                    self.coreml_path(model),
                ) {
                    assets.push(Asset {
                        url: format!("{WHISPER_BASE_URL}/{zip}"),
                        dest,
                        zipped: true,
                    });
                }
                assets
            }
            EngineKind::Parakeet => PARAKEET_FILES
                .iter()
                .map(|file| Asset {
                    url: format!("https://huggingface.co/{}/resolve/main/{file}", model.repo),
                    dest: self.path(model).join(file),
                    zipped: false,
                })
                .collect(),
        }
    }

    /// Ready to transcribe. Files only appear under their final names once
    /// complete, so presence means the download finished.
    pub fn is_downloaded(&self, id: &str) -> bool {
        find(id).is_some_and(|m| self.is_ready(m))
    }

    fn is_ready(&self, model: &ModelInfo) -> bool {
        match model.engine {
            EngineKind::Whisper => self.path(model).is_file(),
            EngineKind::Parakeet => {
                let dir = self.path(model);
                PARAKEET_FILES.iter().all(|f| dir.join(f).is_file())
            }
        }
    }

    fn accelerator(&self, model: &ModelInfo) -> Accelerator {
        match self.coreml_path(model) {
            None => Accelerator::None,
            Some(path) if path.is_dir() => Accelerator::Installed,
            Some(_) => Accelerator::Missing,
        }
    }

    pub fn statuses(&self) -> Vec<ModelStatus> {
        let active = self.active();
        available()
            .map(|m| ModelStatus {
                info: *m,
                downloaded: self.is_ready(m),
                downloading: active.contains_key(m.id),
                accelerator: self.accelerator(m),
                download_mb: m.size_mb
                    + if auto_accelerator(m) {
                        m.accelerator_mb
                    } else {
                        0
                    },
            })
            .collect()
    }

    /// Asks a running download to stop. It ends with a "Download cancelled" error.
    pub fn cancel(&self, id: &str) {
        if let Some(flag) = self.active().get(id) {
            flag.store(true, Ordering::Relaxed);
        }
    }

    pub fn delete(&self, id: &str) -> Result<(), String> {
        let model = find(id).ok_or("Unknown model")?;
        let mut paths = vec![self.path(model)];
        // Large Turbo and its compressed build share one encoder; keep it while either is installed.
        if let Some(coreml) = self.coreml_path(model) {
            let shared = CATALOG.iter().any(|other| {
                other.id != model.id
                    && other.coreml_encoder == model.coreml_encoder
                    && self.is_ready(other)
            });
            if !shared {
                paths.push(coreml);
            }
        }
        for path in paths {
            let result = if path.is_dir() {
                std::fs::remove_dir_all(&path)
            } else {
                std::fs::remove_file(&path)
            };
            if let Err(e) = result
                && e.kind() != std::io::ErrorKind::NotFound
            {
                return Err(e.to_string());
            }
        }
        Ok(())
    }

    /// Downloads whatever the model is still missing, reporting combined progress
    /// a few times a second. `accelerator` asks for the Neural Engine files; by
    /// default they're included only when small. Also adds them to an
    /// already-installed Whisper model.
    pub async fn download(
        &self,
        id: &str,
        accelerator: Option<bool>,
        on_progress: impl Fn(DownloadProgress),
    ) -> Result<(), String> {
        let model = find(id).ok_or("Unknown model")?;
        let cancelled = Arc::new(AtomicBool::new(false));
        {
            let mut active = self.active();
            if active.contains_key(id) {
                return Err("This model is already downloading".into());
            }
            active.insert(id.to_string(), cancelled.clone());
        }
        // Clears the entry however this ends, including if the future is dropped.
        let _active = ActiveDownload { store: self, id };

        let with_accelerator = accelerator.unwrap_or_else(|| auto_accelerator(model));
        self.fetch_missing(model, with_accelerator, &cancelled, &on_progress)
            .await
    }

    async fn fetch_missing(
        &self,
        model: &ModelInfo,
        with_accelerator: bool,
        cancelled: &AtomicBool,
        on_progress: &impl Fn(DownloadProgress),
    ) -> Result<(), String> {
        let missing: Vec<Asset> = self
            .assets(model, with_accelerator)
            .into_iter()
            .filter(|asset| !asset.dest.exists())
            .collect();
        if missing.is_empty() {
            return Ok(());
        }

        let client = reqwest::Client::builder()
            .connect_timeout(CONNECT_TIMEOUT)
            .read_timeout(READ_TIMEOUT)
            .build()
            .map_err(|e| format!("Download failed: {e}"))?;
        let mut sizes = Vec::with_capacity(missing.len());
        for asset in &missing {
            let size = client
                .head(&asset.url)
                .send()
                .await
                .and_then(|r| r.error_for_status())
                .map_err(|e| format!("Download failed: {e}"))?
                .content_length()
                .unwrap_or(0);
            sizes.push(size);
        }
        let total: u64 = sizes.iter().sum();

        // Checked before writing anything, so a full disk is reported up front
        // rather than as a write error minutes in.
        remove_leftovers(&missing, model.id).await;
        if let Some(available) = available_space(&self.dir) {
            check_space(space_needed(model, &missing, &sizes), available)?;
        }

        let mut done = 0;
        let report = |downloaded: u64| {
            on_progress(DownloadProgress {
                id: model.id.into(),
                downloaded,
                total,
            })
        };
        let download = Download {
            client: &client,
            model_id: model.id,
            cancelled,
        };
        for (asset, size) in missing.iter().zip(sizes) {
            download
                .fetch(asset, size, &|bytes| report(done + bytes))
                .await?;
            done += size;
        }
        report(total);
        Ok(())
    }
}

/// Removes a model from `ModelStore::active` when dropped.
struct ActiveDownload<'a> {
    store: &'a ModelStore,
    id: &'a str,
}

impl Drop for ActiveDownload<'_> {
    fn drop(&mut self) {
        self.store.active().remove(self.id);
    }
}

/// What every asset of one model's download shares.
struct Download<'a> {
    client: &'a reqwest::Client,
    /// Names the temporary files (see `Asset::part`).
    model_id: &'a str,
    cancelled: &'a AtomicBool,
}

impl Download<'_> {
    async fn fetch(
        &self,
        asset: &Asset,
        expected: u64,
        on_bytes: &impl Fn(u64),
    ) -> Result<(), String> {
        if self.cancelled.load(Ordering::Relaxed) {
            return Err("Download cancelled".into());
        }
        let dir = asset.dest.parent().ok_or("Invalid model path")?;
        tokio::fs::create_dir_all(dir)
            .await
            .map_err(|e| e.to_string())?;
        let part = asset.part(self.model_id);

        if let Err(e) = self.fetch_to(&asset.url, &part, expected, on_bytes).await {
            let _ = tokio::fs::remove_file(&part).await;
            return Err(e);
        }

        let result = if asset.zipped {
            // Extract into a temporary folder, then move the result into place, so a
            // half-extracted folder never looks installed. Unzipping takes a while,
            // so it runs off the async runtime.
            let staging = asset.staging(self.model_id);
            let (zip, dest) = (part.clone(), asset.dest.clone());
            let installed = tauri::async_runtime::spawn_blocking(move || {
                let result = install_zip(&zip, &staging, &dest);
                let _ = std::fs::remove_dir_all(&staging);
                result
            })
            .await
            .unwrap_or_else(|e| Err(e.to_string()));
            installed.map_err(|e| format!("Couldn't unpack the Neural Engine files: {e}"))
        } else {
            tokio::fs::rename(&part, &asset.dest)
                .await
                .map_err(|e| e.to_string())
        };
        let _ = tokio::fs::remove_file(&part).await;
        result
    }

    /// Streams `url` into `part`, flushed to disk, checking for cancellation as
    /// chunks arrive.
    async fn fetch_to(
        &self,
        url: &str,
        part: &Path,
        expected: u64,
        on_bytes: &impl Fn(u64),
    ) -> Result<(), String> {
        let response = self
            .client
            .get(url)
            .send()
            .await
            .and_then(|r| r.error_for_status())
            .map_err(|e| format!("Download failed: {e}"))?;
        let mut file = tokio::fs::File::create(part)
            .await
            .map_err(|e| e.to_string())?;
        let mut stream = response.bytes_stream();
        let mut downloaded = 0u64;
        let mut last_report = Instant::now();

        while let Some(chunk) = stream.next().await {
            if self.cancelled.load(Ordering::Relaxed) {
                return Err("Download cancelled".into());
            }
            let chunk = chunk.map_err(|e| format!("Download interrupted: {e}"))?;
            file.write_all(&chunk).await.map_err(|e| e.to_string())?;
            downloaded += chunk.len() as u64;
            if last_report.elapsed() >= PROGRESS_INTERVAL {
                on_bytes(downloaded);
                last_report = Instant::now();
            }
        }
        if expected > 0 && downloaded != expected {
            return Err(format!(
                "Download incomplete: got {downloaded} of {expected} bytes"
            ));
        }
        // Flushed to disk before it's renamed into place, so a power loss can't
        // leave a truncated model under its final name. `flush` reports any
        // failed buffered write, which `sync_all` alone would not.
        file.flush().await.map_err(|e| e.to_string())?;
        file.sync_all().await.map_err(|e| e.to_string())
    }
}

/// Unzips `zip` into `staging` and moves the folder named like `dest` into place.
fn install_zip(zip: &Path, staging: &Path, dest: &Path) -> Result<(), String> {
    let _ = std::fs::remove_dir_all(staging);
    platform::extract_zip(zip, staging)?;
    let name = dest.file_name().ok_or("Invalid model path")?;
    match std::fs::rename(staging.join(name), dest) {
        Ok(()) => Ok(()),
        // Another model sharing these files finished first.
        Err(_) if dest.is_dir() => Ok(()),
        Err(e) => Err(e.to_string()),
    }
}

/// Left free after a download, so it never fills the disk to the last byte.
const SPACE_MARGIN: u64 = 100 * MIB;
const MIB: u64 = 1024 * 1024;
/// The catalog's sizes are in decimal megabytes, as the files are published.
const CATALOG_MB: u64 = 1_000_000;

/// Deletes what an interrupted earlier download of this model left behind, so
/// it doesn't count against the free space. Other models' files are untouched,
/// and this model can't be downloading twice.
async fn remove_leftovers(missing: &[Asset], model_id: &str) {
    for asset in missing {
        let _ = tokio::fs::remove_file(asset.part(model_id)).await;
        let _ = tokio::fs::remove_dir_all(asset.staging(model_id)).await;
    }
}

/// Disk space the download takes at its peak, given each missing asset's size
/// (0 when the server didn't say). A zip and the folder it extracts to exist
/// together until the zip is removed. Unknown sizes fall back to the catalog.
fn space_needed(model: &ModelInfo, missing: &[Asset], sizes: &[u64]) -> u64 {
    let known = missing
        .iter()
        .zip(sizes)
        .map(|(asset, &size)| if asset.zipped { 2 * size } else { size })
        .sum();
    if !sizes.contains(&0) {
        return known;
    }
    let mut estimate_mb = 0;
    if missing.iter().any(|a| !a.zipped) {
        estimate_mb += u64::from(model.size_mb);
    }
    if missing.iter().any(|a| a.zipped) {
        estimate_mb += 2 * u64::from(model.accelerator_mb);
    }
    known.max(estimate_mb * CATALOG_MB)
}

/// Refuses a download that won't fit with `SPACE_MARGIN` to spare.
fn check_space(needed: u64, available: u64) -> Result<(), String> {
    let needed = needed + SPACE_MARGIN;
    if available >= needed {
        return Ok(());
    }
    Err(format!(
        "Not enough disk space: this download needs {} and only {} is free",
        format_size(needed),
        format_size(available)
    ))
}

/// Free space on the disk holding `dir`, or `None` when it can't be told, in
/// which case the download goes ahead unchecked.
fn available_space(dir: &Path) -> Option<u64> {
    // The models folder doesn't exist before the first download.
    let dir = dir.ancestors().find(|p| p.exists())?;
    let disks = Disks::new_with_refreshed_list_specifics(DiskRefreshKind::nothing().with_storage());
    let mount = mount_point_of(dir, disks.list().iter().map(|d| d.mount_point()))?;
    let disk = disks.list().iter().find(|d| d.mount_point() == mount)?;
    same_device(dir, mount).then(|| disk.available_space())
}

/// The mount point `path` is under: the longest one containing it.
fn mount_point_of<'a>(path: &Path, mounts: impl Iterator<Item = &'a Path>) -> Option<&'a Path> {
    mounts
        .filter(|mount| path.starts_with(mount))
        .max_by_key(|mount| mount.as_os_str().len())
}

/// Guards against reading the wrong disk: `sysinfo` doesn't list some mounts
/// (tmpfs, network drives), which would otherwise match a parent like `/`.
#[cfg(unix)]
fn same_device(a: &Path, b: &Path) -> bool {
    use std::os::unix::fs::MetadataExt;
    match (std::fs::metadata(a), std::fs::metadata(b)) {
        (Ok(a), Ok(b)) => a.dev() == b.dev(),
        _ => false,
    }
}

#[cfg(not(unix))]
fn same_device(_: &Path, _: &Path) -> bool {
    true
}

/// Sizes as the app shows download progress: binary units.
fn format_size(bytes: u64) -> String {
    let mb = bytes as f64 / MIB as f64;
    if mb >= 1024.0 {
        format!("{:.1} GB", mb / 1024.0)
    } else {
        format!("{mb:.0} MB")
    }
}

/// Whether a model's Neural Engine files download with it by default on this OS.
fn auto_accelerator(model: &ModelInfo) -> bool {
    platform::NEURAL_ENGINE
        && model.coreml_encoder.is_some()
        && model.accelerator_mb <= AUTO_ACCELERATOR_MB
}

fn with_suffix(path: &Path, suffix: &str) -> PathBuf {
    let mut name = path.file_name().unwrap_or_default().to_os_string();
    name.push(suffix);
    path.with_file_name(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_ids_are_unique() {
        let mut ids: Vec<_> = CATALOG.iter().map(|m| m.id).collect();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), CATALOG.len());
    }

    #[test]
    fn language_support() {
        let v3 = find("parakeet-tdt-v3").unwrap();
        assert!(v3.supports_language("auto"));
        assert!(v3.supports_language("de"));
        assert!(!v3.supports_language("hi"));
        assert!(find("large-v3-turbo").unwrap().supports_language("hi"));
        assert!(!find("small-en").unwrap().supports_language("fr"));
    }

    #[test]
    fn parakeet_assets_live_in_one_folder() {
        let store = ModelStore::new(PathBuf::from("/models"));
        let assets = store.assets(find("parakeet-tdt-v2").unwrap(), true);
        assert_eq!(assets.len(), PARAKEET_FILES.len());
        assert!(
            assets
                .iter()
                .all(|a| a.dest.starts_with("/models/parakeet-tdt-0.6b-v2-int8"))
        );
        assert!(
            assets[0]
                .url
                .starts_with("https://huggingface.co/istupakov/parakeet-tdt-0.6b-v2-onnx/")
        );
    }

    /// A fresh models directory under the system temp dir, removed on drop.
    struct TempStore {
        store: ModelStore,
        root: PathBuf,
    }

    impl TempStore {
        fn new() -> Self {
            let root =
                std::env::temp_dir().join(format!("speaktype-test-{}", uuid::Uuid::new_v4()));
            std::fs::create_dir_all(&root).unwrap();
            Self {
                store: ModelStore::new(root.clone()),
                root,
            }
        }

        fn touch(&self, model: &ModelInfo) {
            let path = self.store.path(model);
            match model.engine {
                EngineKind::Whisper => std::fs::write(path, b"ggml").unwrap(),
                EngineKind::Parakeet => {
                    std::fs::create_dir_all(&path).unwrap();
                    for file in PARAKEET_FILES {
                        std::fs::write(path.join(file), b"onnx").unwrap();
                    }
                }
            }
        }
    }

    impl Drop for TempStore {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn whisper_assets_add_the_encoder_only_when_asked_and_supported() {
        let store = ModelStore::new(PathBuf::from("/models"));
        let model = find("base").unwrap();

        let plain = store.assets(model, false);
        assert_eq!(plain.len(), 1);
        assert_eq!(plain[0].dest, PathBuf::from("/models/ggml-base.bin"));
        assert_eq!(plain[0].url, format!("{WHISPER_BASE_URL}/ggml-base.bin"));
        assert!(!plain[0].zipped);

        let accelerated = store.assets(model, true);
        if platform::NEURAL_ENGINE {
            assert_eq!(accelerated.len(), 2);
            let encoder = &accelerated[1];
            assert!(encoder.zipped);
            assert_eq!(
                encoder.dest,
                PathBuf::from("/models/ggml-base-encoder.mlmodelc")
            );
            assert!(encoder.url.ends_with("/ggml-base-encoder.mlmodelc.zip"));
        } else {
            assert_eq!(accelerated.len(), 1);
        }
    }

    #[test]
    fn statuses_include_small_encoders_in_the_download_size() {
        let store = ModelStore::new(PathBuf::from("/nonexistent/models"));
        let statuses = store.statuses();
        assert_eq!(statuses.len(), available().count());
        let size = |id: &str| {
            statuses
                .iter()
                .find(|s| s.info.id == id)
                .unwrap()
                .download_mb
        };
        let small = if platform::NEURAL_ENGINE {
            142 + 36
        } else {
            142
        };
        assert_eq!(size("base"), small);
        // Turbo's 1.1 GB encoder is an optional extra.
        assert_eq!(size("large-v3-turbo"), 1624);
        assert!(statuses.iter().all(|s| !s.downloaded && !s.downloading));
    }

    #[test]
    fn parakeet_is_ready_only_with_every_file() {
        let temp = TempStore::new();
        let model = find("parakeet-tdt-v3").unwrap();
        assert!(!temp.store.is_downloaded(model.id));
        temp.touch(model);
        assert!(temp.store.is_downloaded(model.id));
        std::fs::remove_file(temp.store.path(model).join(PARAKEET_FILES[1])).unwrap();
        assert!(!temp.store.is_downloaded(model.id));
        assert!(!temp.store.is_downloaded("no-such-model"));
    }

    #[test]
    fn delete_keeps_an_encoder_another_model_still_uses() {
        let temp = TempStore::new();
        let turbo = find("large-v3-turbo").unwrap();
        let compressed = find("large-v3-turbo-q5").unwrap();
        temp.touch(turbo);
        temp.touch(compressed);
        let encoder = temp.store.coreml_path(turbo);
        if let Some(encoder) = &encoder {
            std::fs::create_dir_all(encoder).unwrap();
            assert_eq!(temp.store.accelerator(turbo), Accelerator::Installed);
        }

        temp.store.delete(turbo.id).unwrap();
        assert!(!temp.store.is_downloaded(turbo.id));
        if let Some(encoder) = &encoder {
            assert!(encoder.is_dir(), "still used by the compressed model");
        }

        temp.store.delete(compressed.id).unwrap();
        if let Some(encoder) = &encoder {
            assert!(!encoder.exists());
        }
        // Deleting something that isn't installed is fine; unknown ids aren't.
        temp.store.delete(compressed.id).unwrap();
        assert!(temp.store.delete("no-such-model").is_err());
    }

    #[test]
    fn download_of_an_installed_model_needs_no_network_and_clears_its_entry() {
        let temp = TempStore::new();
        let model = find("tiny").unwrap();
        temp.touch(model);

        let result = tauri::async_runtime::block_on(temp.store.download(
            model.id,
            Some(false),
            |_| panic!("nothing to report"),
        ));
        assert_eq!(result, Ok(()));
        assert!(temp.store.active().is_empty());

        let unknown =
            tauri::async_runtime::block_on(temp.store.download("no-such-model", None, |_| {}));
        assert!(unknown.is_err());
    }

    #[test]
    fn a_second_download_of_the_same_model_is_refused() {
        let temp = TempStore::new();
        let flag = Arc::new(AtomicBool::new(false));
        temp.store.active().insert("tiny".into(), flag.clone());

        let result = tauri::async_runtime::block_on(temp.store.download("tiny", None, |_| {}));
        assert_eq!(result, Err("This model is already downloading".into()));
        // The refused attempt must not clear the running download's entry.
        assert!(temp.store.active().contains_key("tiny"));

        temp.store.cancel("tiny");
        assert!(flag.load(Ordering::Relaxed));
    }

    #[test]
    fn active_entry_is_removed_when_a_download_is_dropped() {
        let store = ModelStore::new(PathBuf::from("/models"));
        store
            .active()
            .insert("tiny".into(), Arc::new(AtomicBool::new(false)));
        drop(ActiveDownload {
            store: &store,
            id: "tiny",
        });
        assert!(store.active().is_empty());
    }

    #[test]
    fn temporary_names_extend_the_file_name() {
        assert_eq!(
            with_suffix(Path::new("/m/ggml-base.bin"), ".base.part"),
            PathBuf::from("/m/ggml-base.bin.base.part")
        );
        assert_eq!(
            with_suffix(Path::new("/m/enc.mlmodelc"), ".tiny.extracting"),
            PathBuf::from("/m/enc.mlmodelc.tiny.extracting")
        );
    }

    fn asset(dest: &str, zipped: bool) -> Asset {
        Asset {
            url: String::new(),
            dest: PathBuf::from(dest),
            zipped,
        }
    }

    #[test]
    fn a_download_that_wont_fit_is_refused_with_the_sizes() {
        let gb = 1024 * MIB;
        assert_eq!(check_space(gb, 2 * gb), Ok(()));
        // Fits, but not with the margin to spare.
        assert!(check_space(gb, gb + SPACE_MARGIN / 2).is_err());
        assert_eq!(
            check_space(3 * gb / 2, 400 * MIB),
            Err("Not enough disk space: this download needs 1.6 GB and only 400 MB is free".into())
        );
    }

    #[test]
    fn space_needed_counts_zips_twice_and_falls_back_to_the_catalog() {
        let model = find("small-en").unwrap();
        let files = [
            asset("/m/ggml-small.en.bin", false),
            asset("/m/ggml-small.en-encoder.mlmodelc", true),
        ];
        assert_eq!(space_needed(model, &files, &[500, 100]), 700);
        // Sizes the server didn't report come from the catalog: 466 MB + 2 × 155 MB.
        assert_eq!(space_needed(model, &files, &[0, 100]), 776 * CATALOG_MB);
        assert_eq!(
            space_needed(model, &files[1..], &[0]),
            2 * 155 * CATALOG_MB,
            "only the missing encoder"
        );
    }

    #[test]
    fn a_path_is_on_the_longest_mount_point_containing_it() {
        let mounts = [
            Path::new("/"),
            Path::new("/home"),
            Path::new("/home/me/media"),
        ];
        let mount = |path| mount_point_of(Path::new(path), mounts.into_iter());
        assert_eq!(mount("/home/me/.local/share"), Some(Path::new("/home")));
        assert_eq!(
            mount("/home/me/media/models"),
            Some(Path::new("/home/me/media"))
        );
        // Whole components only: /home2 isn't under /home.
        assert_eq!(mount("/home2/models"), Some(Path::new("/")));
        assert_eq!(
            mount_point_of(Path::new("/models"), std::iter::empty()),
            None
        );
    }

    #[test]
    fn leftovers_of_an_interrupted_download_are_removed() {
        let temp = TempStore::new();
        let model = find("base").unwrap();
        let missing = temp.store.assets(model, true);
        for asset in &missing {
            std::fs::write(asset.part(model.id), b"partial").unwrap();
            std::fs::create_dir_all(asset.staging(model.id)).unwrap();
        }
        // Another model downloading the same file keeps its own.
        let other = missing[0].part("base-en");
        std::fs::write(&other, b"partial").unwrap();

        tauri::async_runtime::block_on(remove_leftovers(&missing, model.id));
        for asset in &missing {
            assert!(!asset.part(model.id).exists());
            assert!(!asset.staging(model.id).exists());
        }
        assert!(other.exists());
    }
}
