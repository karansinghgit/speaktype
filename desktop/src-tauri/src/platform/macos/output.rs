//! Temporarily silence the current macOS output device during microphone capture.
//! Playback continues in other apps; only the output device is muted.

use std::{ffi::c_void, mem::size_of, ptr, sync::Mutex};

type AudioObjectId = u32;

#[repr(C)]
struct PropertyAddress {
    selector: u32,
    scope: u32,
    element: u32,
}

const SYSTEM_OBJECT: AudioObjectId = 1;
const DEFAULT_OUTPUT: u32 = u32::from_be_bytes(*b"dOut");
const MUTE: u32 = u32::from_be_bytes(*b"mute");
const VIRTUAL_MAIN_VOLUME: u32 = u32::from_be_bytes(*b"vmvc");
const GLOBAL: u32 = u32::from_be_bytes(*b"glob");
const OUTPUT: u32 = u32::from_be_bytes(*b"outp");

#[link(name = "CoreAudio", kind = "framework")]
unsafe extern "C" {
    #[link_name = "AudioObjectHasProperty"]
    fn has_property(object: AudioObjectId, address: *const PropertyAddress) -> u8;
    #[link_name = "AudioObjectIsPropertySettable"]
    fn is_property_settable(
        object: AudioObjectId,
        address: *const PropertyAddress,
        settable: *mut u8,
    ) -> i32;
    #[link_name = "AudioObjectGetPropertyData"]
    fn get_property(
        object: AudioObjectId,
        address: *const PropertyAddress,
        qualifier_size: u32,
        qualifier: *const c_void,
        data_size: *mut u32,
        data: *mut c_void,
    ) -> i32;
    #[link_name = "AudioObjectSetPropertyData"]
    fn set_property(
        object: AudioObjectId,
        address: *const PropertyAddress,
        qualifier_size: u32,
        qualifier: *const c_void,
        data_size: u32,
        data: *const c_void,
    ) -> i32;
}

fn address(selector: u32, scope: u32) -> PropertyAddress {
    PropertyAddress {
        selector,
        scope,
        element: 0,
    }
}

fn read<T: Copy + Default>(device: AudioObjectId, property: &PropertyAddress) -> Option<T> {
    let mut value = T::default();
    let mut size = size_of::<T>() as u32;
    // SAFETY: Call sites use only C-compatible u32 and f32 buffers.
    let status = unsafe {
        get_property(
            device,
            property,
            0,
            ptr::null(),
            &mut size,
            (&mut value as *mut T).cast(),
        )
    };
    (status == 0 && size == size_of::<T>() as u32).then_some(value)
}

fn write<T: Copy>(device: AudioObjectId, property: &PropertyAddress, value: T) -> bool {
    // SAFETY: Call sites pass only C-compatible u32 and f32 values.
    unsafe {
        set_property(
            device,
            property,
            0,
            ptr::null(),
            size_of::<T>() as u32,
            (&value as *const T).cast(),
        ) == 0
    }
}

fn settable(device: AudioObjectId, property: &PropertyAddress) -> bool {
    // SAFETY: CoreAudio reads the address and writes one Boolean byte.
    if unsafe { has_property(device, property) } == 0 {
        return false;
    }
    let mut value = 0u8;
    // SAFETY: value is a valid Boolean output buffer.
    unsafe { is_property_settable(device, property, &mut value) == 0 && value != 0 }
}

fn default_output() -> Option<AudioObjectId> {
    read::<u32>(SYSTEM_OBJECT, &address(DEFAULT_OUTPUT, GLOBAL)).filter(|&id| id != 0)
}

enum Restore {
    Mute {
        device: AudioObjectId,
    },
    Volume {
        device: AudioObjectId,
        previous: f32,
    },
}

fn silence_default_output() -> Result<Option<Restore>, &'static str> {
    let device = default_output().ok_or("No default output device")?;
    let mute = address(MUTE, OUTPUT);
    if settable(device, &mute)
        && let Some(was_muted) = read::<u32>(device, &mute)
    {
        if was_muted != 0 {
            return Ok(None);
        }
        if write(device, &mute, 1u32) {
            return Ok(Some(Restore::Mute { device }));
        }
    }

    let volume = address(VIRTUAL_MAIN_VOLUME, OUTPUT);
    if settable(device, &volume)
        && let Some(previous) = read::<f32>(device, &volume)
    {
        if previous == 0.0 {
            return Ok(None);
        }
        if write(device, &volume, 0.0f32) {
            return Ok(Some(Restore::Volume { device, previous }));
        }
    }
    Err("The output device has no writable mute or volume control")
}

fn restore(state: Restore) {
    match state {
        Restore::Mute { device } => {
            let property = address(MUTE, OUTPUT);
            // Leave a volume or mute change made by the user during recording alone.
            if read::<u32>(device, &property) == Some(1) && !write(device, &property, 0u32) {
                eprintln!("[audio] couldn't restore output mute");
            }
        }
        Restore::Volume { device, previous } => {
            let property = address(VIRTUAL_MAIN_VOLUME, OUTPUT);
            if read::<f32>(device, &property) == Some(0.0) && !write(device, &property, previous) {
                eprintln!("[audio] couldn't restore output volume");
            }
        }
    }
}

static MUTED_OUTPUT: Mutex<Option<Restore>> = Mutex::new(None);

pub struct OutputMuteGuard {
    active: bool,
}

impl OutputMuteGuard {
    pub fn mute() -> Self {
        let mut state = MUTED_OUTPUT
            .lock()
            .unwrap_or_else(|poison| poison.into_inner());
        if state.is_some() {
            return Self { active: false };
        }
        match silence_default_output() {
            Ok(restore) => {
                let active = restore.is_some();
                *state = restore;
                Self { active }
            }
            Err(error) => {
                eprintln!("[audio] couldn't mute output: {error}");
                Self { active: false }
            }
        }
    }
}

impl Drop for OutputMuteGuard {
    fn drop(&mut self) {
        if self.active {
            restore_output_on_exit();
        }
    }
}

pub fn restore_output_on_exit() {
    let mut state = MUTED_OUTPUT
        .lock()
        .unwrap_or_else(|poison| poison.into_inner());
    if let Some(previous) = state.take() {
        restore(previous);
    }
}
