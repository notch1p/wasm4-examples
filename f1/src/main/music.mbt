let pause = 235U

let musNone = 0U

let musFailed = 2U

let music_failed : FixedArray[UInt] = [
  850,
  pause * 2,
  0,
  pause,
  850,
  pause,
  0,
  pause,
  850,
  pause,
  0,
  pause,
  850,
  pause * 2,
  0,
  pause,
]

struct MusicStat {
  mut music_note : UInt
  mut music_tempo : UInt
  mut music_loop : Bool
  mut music_on : Bool
  mut sound_on : Bool
  mut sfx_sustain : UInt
  mut prev_music : UInt
  sfx_setting_note : Bool
  mut sfx_sustain_zero_set : Bool
  mut selecting_music : Bool
  mut music_length : UInt
  mut music_array : FixedArray[UInt]
}

pub fn processSound(self : MusicStat) -> Unit {
  if self.sfx_setting_note || self.selecting_music {
    return
  }
  self.musicTimer()
  if self.sfx_sustain == 0 {
    if not(self.sfx_sustain_zero_set) {
      @wasm4.tone(
        (0, 0),
        @wasm4.ADSR::new(self.sfx_sustain),
        @wasm4.ADSRVolume::new(0),
        @wasm4.ToneFlag::new(channel=@wasm4.ToneChannel::Pulse1),
      )
      self.sfx_sustain_zero_set = true
    }
  } else {
    self.sfx_sustain -= 1
  }
}

pub fn selectMusic(self : MusicStat, music : UInt, mloop : Bool) -> Unit {
  if self.prev_music != music {
    self.selecting_music = true
    self.prev_music = music
    self.music_array = FixedArray::make(255, 0)
    match music {
      2 => {
        music_failed.blit_to(self.music_array, len=16)
        self.music_length = music_failed.length().to_uint()
      }
      _ => ()
    }
    self.music_note = 0
    self.music_tempo = 0
    self.music_loop = mloop
    self.selecting_music = false
  }
}

pub fn musicTimer(self : MusicStat) -> Unit {
  if self.selecting_music {
    return
  }
  if self.music_tempo == 0 {
    if self.music_on {
      playNote(self)
    }
  } else {
    self.music_tempo -= 1
  }
}

pub fn playNote(self : MusicStat) -> Unit {
  if self.music_note < self.music_length {
    @wasm4.tone(
      (self.music_array[self.music_note.to_int()], 0),
      @wasm4.ADSR::new(100),
      @wasm4.ADSRVolume::new(50),
      @wasm4.ToneFlag::new(
        channel=@wasm4.ToneChannel::Pulse2,
        mode=@wasm4.ToneMode::Duty_3_4,
      ),
    )
    self.music_tempo = self.music_array[self.music_note.to_int() + 1] *
      60 /
      1000
    self.music_note += 2
    if self.music_note > self.music_length - 1 {
      if self.music_loop {
        self.music_note = 0
      }
    }
  }
}

pub fn playSound(self : MusicStat, freq : UInt) -> Unit {
  if not(self.sound_on) {
    return
  }
  @wasm4.tone(
    (freq, 0),
    @wasm4.ADSR::new(5),
    @wasm4.ADSRVolume::new(100),
    @wasm4.ToneFlag::new(channel=@wasm4.ToneChannel::Pulse1),
  )
}

pub fn playTickSound(self : MusicStat) -> Unit {
  self.playSound(750)
}

pub fn MusicStat::new() -> MusicStat {
  {
    prev_music: 0,
    music_note: 0,
    music_length: 0,
    music_tempo: 0,
    music_loop: false,
    selecting_music: true,
    music_on: true,
    sound_on: false,
    sfx_sustain: 0,
    sfx_setting_note: true,
    sfx_sustain_zero_set: true,
    music_array: FixedArray::make(255, 0),
  }
}
