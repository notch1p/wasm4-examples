enum GameState {
  GSIntroInit
  GSIntro
  GSGameInit
  GSGame
  GSGameOverInit
  GSGameOver
}

struct GameStat {
  mut game_state : GameState
  mut enemy_state : FixedArray[FixedArray[Bool]]
  mut player_state : FixedArray[Bool]
  mut hit_pos : Int
  mut lives_lost : Int
  mut score : UInt
  mut high_score : UInt
  mut teller : Int
  mut flashes_delay : Int
  mut flashes : Int
  mut delay : Int
  mut can_move : Bool
  mut crash_sound_played : Bool
  mut rng : @random.Rand
}

let gs : GameStat = GameStat::new()

let frames_drawn : Ref[UInt] = Ref::new(0U)

let music : MusicStat = MusicStat::new()

let prevgp1 : PrevGamePad = {
  button_1: false,
  button_2: false,
  button_down: false,
  button_left: false,
  button_right: false,
  button_up: false,
}

fn u32_to_u8(u32 : UInt) -> Bytes {
  let b = Bytes::new(4)
  b[3] = (u32 >> 24).to_byte()
  b[2] = (u32 >> 16).to_byte()
  b[1] = (u32 >> 8).to_byte()
  b[0] = u32.to_byte()
  b
}

fn u8_to_u32(u8 : Bytes) -> UInt {
  (u8[3].to_uint() << 24) |
  (u8[2].to_uint() << 16) |
  (u8[1].to_uint() << 8) |
  u8[0].to_uint()
}

pub fn save_settings(self : GameStat) -> Unit {
  @wasm4.disk_write(u32_to_u8(self.high_score), 4) |> ignore
}

pub fn load_settings(self : GameStat) -> Unit {
  let b = Bytes::new(4)
  @wasm4.disk_read(b, 4) |> ignore
  self.high_score = u8_to_u32(b)
}

pub fn set_hi(self : GameStat, v : UInt) -> Unit {
  if v > self.high_score {
    self.high_score = v
    self.save_settings()
  }
}

pub fn draw_score_bar(
  empty : Bool,
  score : UInt,
  hiscore : UInt,
  lives_lost : Int
) -> Unit {
  if empty {
    return
  }
  @wasm4.set_draw_colors(2, index=1)
  @wasm4.set_draw_colors(4, index=2)
  @wasm4.set_draw_colors(0, index=3)
  @wasm4.set_draw_colors(0, index=4)
  @wasm4.text(score.to_string(), 15, 2)
  @wasm4.text("Hi " + hiscore.to_string(), 65, 2)
  let s = Iter::repeat("X").take(lives_lost).fold(init="", String::op_add)
  @wasm4.text(s, 135, 2)
}

pub fn draw_game(self : GameStat) -> Unit {
  @wasm4.set_draw_colors(2, index=1)
  @wasm4.set_draw_colors(1, index=2)
  @wasm4.set_draw_colors(3, index=3)
  @wasm4.set_draw_colors(4, index=4)
  for x = 0; x < 3; x = x + 1 {
    for y = 0; y < 3; y = y + 1 {
      if self.enemy_state[x][y] {
        @wasm4.blit(
          @wasm4.sprite(enemy),
          27 + x * 42,
          16 + y * 40,
          enemy_width,
          enemy_height,
          @wasm4.BlitFlag::{
            one_bit_per_pixel: false,
            rotate: false,
            flip_x: false,
            flip_y: false,
          },
        )
      }
    }
  }
  for x = 0; x < 3; x = x + 1 {
    if self.player_state[x] {
      @wasm4.blit(
        @wasm4.sprite(player),
        27 + x * 42,
        130,
        player_width,
        player_height,
        @wasm4.BlitFlag::{
          one_bit_per_pixel: false,
          rotate: false,
          flip_x: false,
          flip_y: false,
        },
      )
    }
  }
}

pub fn moveEnemy(self : GameStat) -> Unit {
  for x = 0; x < 3; x = x + 1 {
    for y = 2; y >= 1; y = y - 1 {
      self.enemy_state[x][y] = self.enemy_state[x][y - 1]
    }
  }
  for x = 0; x < 3; x = x + 1 {
    self.enemy_state[x][0] = false
  }
  for x = 0; x <= 1; x = x + 1 {
    self.enemy_state[self.rng.int() % 3][0] = true
  }
}

pub fn moveLeft(self : GameStat) -> Unit {
  for x = 0; x < 2; x = x + 1 {
    if self.player_state[x + 1] {
      self.player_state[x] = true
      self.player_state[x + 1] = false
    }
  }
}

pub fn moveRight(self : GameStat) -> Unit {
  for x = 2; x >= 1; x = x - 1 {
    if self.player_state[x - 1] {
      self.player_state[x] = true
      self.player_state[x - 1] = false
    }
  }
}

pub fn isCollided(self : GameStat) -> Bool {
  let mut t = false
  for x = 0; x < 3; x = x + 1 {
    if self.player_state[x] && self.enemy_state[x][2] {
      t = true
      self.hit_pos = x
    }
  }
  t
}

pub fn hit_flash(self : GameStat) -> Unit {
  self.player_state[self.hit_pos] = not(self.player_state[self.hit_pos])
  self.enemy_state[self.hit_pos][2] = not(self.enemy_state[self.hit_pos][2])
}

pub fn GameStat::new() -> GameStat {
  let enemy_state : FixedArray[FixedArray[Bool]] = [
    [false, false, false],
    [false, false, false],
    [false, false, false],
  ]
  let player_state : FixedArray[Bool] = [false, false, false]
  player_state[1] = true
  {
    enemy_state,
    player_state,
    teller: 25,
    flashes_delay: 14,
    flashes: 0,
    can_move: true,
    score: 0,
    delay: 60,
    lives_lost: 0,
    crash_sound_played: false,
    game_state: GSIntroInit,
    hit_pos: 0,
    high_score: 0,
    rng: @random.new(),
  }
}

pub fn reset(self : GameStat) -> Unit {
  self.player_state[1] = true
  self.teller = 25
  self.flashes_delay = 14
  self.flashes = 0
  self.can_move = true
  self.score = 0
  self.delay = 60
  self.lives_lost = 0
  self.crash_sound_played = false
  self.game_state = GSIntroInit
  self.hit_pos = 0
  self.high_score = 0
  self.rng = @random.new()
  let enemy_state : FixedArray[FixedArray[Bool]] = [
    [false, false, false],
    [false, false, false],
    [false, false, false],
  ]
  let player_state : FixedArray[Bool] = [false, false, false]
  player_state[1] = true
  self.enemy_state = enemy_state
  self.player_state = player_state
}

pub fn game(self : GameStat, music : MusicStat) -> Unit {
  let gp1 = @wasm4.get_gamepad()
  match self.game_state {
    GSGameInit => {
      self.reset()
      self.game_state = GSGame
    }
    _ => ()
  }
  if butRel(gp1.button_left, prevgp1.button_left) {
    if self.can_move {
      self.moveLeft()
    }
  } else if butRel(gp1.button_right, prevgp1.button_right) {
    if self.can_move {
      self.moveRight()
    }
  }
  @wasm4.set_draw_colors(3, index=1)
  @wasm4.set_draw_colors(4, index=2)
  @wasm4.set_draw_colors(2, index=3)
  @wasm4.set_draw_colors(1, index=4)
  @wasm4.blit(
    @wasm4.sprite(background),
    0,
    0,
    160,
    160,
    @wasm4.BlitFlag::{
      one_bit_per_pixel: false,
      rotate: false,
      flip_x: false,
      flip_y: false,
    },
  )
  self.teller += 1
  if self.teller >= self.delay {
    if not(self.isCollided()) && self.can_move {
      self.teller = 0
      for x = 0; x < 3; x = x + 1 {
        if self.enemy_state[x][2] {
          self.score += 10
          self.set_hi(self.score)
          if self.score % 100 == 0 && self.delay > 18 {
            self.delay -= 1
          }
        }
      }
      self.moveEnemy()
      music.playTickSound()
    } else {
      if not(self.crash_sound_played) {
        music.selectMusic(musNone, false)
        music.selectMusic(musFailed, false)
        self.crash_sound_played = true
      }
      self.can_move = false
      self.flashes_delay += 1
      if self.flashes_delay == 30 {
        self.flashes += 1
        self.hit_flash()
        self.flashes_delay = 0
        if self.flashes == 6 {
          self.flashes = 0
          self.can_move = true
          self.teller = 0
          self.crash_sound_played = false
          self.enemy_state[self.hit_pos][2] = false
          self.lives_lost += 1
          self.flashes_delay = 14
          if self.lives_lost == 3 {
            self.game_state = GSGameOverInit
          }
        }
      }
    }
  }
  self.draw_game()
  draw_score_bar(false, self.score, self.high_score, self.lives_lost)
}

pub fn gameover(self : GameStat) -> Unit {
  match self.game_state {
    GSGameOverInit => self.game_state = GSGameOver
    _ => ()
  }
  @wasm4.set_draw_colors(2, index=1)
  @wasm4.set_draw_colors(4, index=2)
  @wasm4.set_draw_colors(0, index=3)
  @wasm4.set_draw_colors(0, index=4)
  @wasm4.text("Game Over", 80, 80)
  let gp1 = @wasm4.get_gamepad()
  if butRel(gp1.button_1, prevgp1.button_1) ||
    butRel(gp1.button_2, prevgp1.button_2) ||
    butRel(gp1.button_down, prevgp1.button_down) ||
    butRel(gp1.button_left, prevgp1.button_left) ||
    butRel(gp1.button_right, prevgp1.button_right) ||
    butRel(gp1.button_up, prevgp1.button_up) {
    self.game_state = GSGameInit
  }
  @wasm4.set_draw_colors(3, index=1)
  @wasm4.set_draw_colors(4, index=2)
  @wasm4.set_draw_colors(2, index=3)
  @wasm4.set_draw_colors(1, index=4)
  @wasm4.blit(
    @wasm4.sprite(background),
    0,
    0,
    160,
    160,
    @wasm4.BlitFlag::{
      one_bit_per_pixel: false,
      rotate: false,
      flip_x: false,
      flip_y: false,
    },
  )
  self.draw_game()
  draw_score_bar(false, self.score, self.high_score, self.lives_lost)
}

pub fn flashIntro(self : GameStat) -> Unit {
  for x = 0; x < 3; x = x + 1 {
    for y = 0; y < 3; y = y + 1 {
      self.enemy_state[x][y] = not(self.enemy_state[x][y])
    }
  }
  for x = 0; x < 3; x = x + 1 {
    self.player_state[x] = not(self.player_state[x])
  }
}

pub fn intro(self : GameStat) -> Unit {
  match self.game_state {
    GSIntroInit => {
      self.flashes_delay = 0
      self.game_state = GSIntro
    }
    _ => ()
  }
  let gp1 = @wasm4.get_gamepad()
  if butRel(gp1.button_1, prevgp1.button_1) ||
    butRel(gp1.button_2, prevgp1.button_2) ||
    butRel(gp1.button_down, prevgp1.button_down) ||
    butRel(gp1.button_left, prevgp1.button_left) ||
    butRel(gp1.button_right, prevgp1.button_right) ||
    butRel(gp1.button_up, prevgp1.button_up) {
    self.game_state = GSGameInit
  }
  @wasm4.set_draw_colors(3, index=1)
  @wasm4.set_draw_colors(4, index=2)
  @wasm4.set_draw_colors(2, index=3)
  @wasm4.set_draw_colors(1, index=4)
  @wasm4.blit(
    @wasm4.sprite(background),
    0,
    0,
    160,
    160,
    @wasm4.BlitFlag::{
      one_bit_per_pixel: false,
      rotate: false,
      flip_x: false,
      flip_y: false,
    },
  )
  self.flashes_delay += 1
  if self.flashes_delay == 25 {
    self.flashes_delay = 0
    self.flashIntro()
  }
  self.draw_game()
  draw_score_bar(not(self.player_state[0]), 88888, 88888, 3)
}

pub struct PrevGamePad {
  mut button_1 : Bool
  mut button_2 : Bool
  mut button_left : Bool
  mut button_right : Bool
  mut button_up : Bool
  mut button_down : Bool
} derive(Eq, Default)

pub fn update() -> Unit {
  music.processSound()
  match gs.game_state {
    GSIntroInit => gs.intro()
    GSIntro => gs.intro()
    GSGameInit => gs.game(music)
    GSGame => gs.game(music)
    GSGameOverInit => gs.gameover()
    GSGameOver => gs.gameover()
  }
  frames_drawn.val += 1
  let gp1 = @wasm4.get_gamepad()
  prevgp1.button_1 = gp1.button_1
  prevgp1.button_2 = gp1.button_2
  prevgp1.button_down = gp1.button_down
  prevgp1.button_left = gp1.button_left
  prevgp1.button_right = gp1.button_right
  prevgp1.button_up = gp1.button_up
}

pub fn butRel(cur_button : Bool, prev_button : Bool) -> Bool {
  return cur_button && not(prev_button)
}

pub fn start() -> Unit {
  @wasm4.set_palette(1, @wasm4.rgb(0xacacac))
  @wasm4.set_palette(2, @wasm4.rgb(0xf3f3f3))
  @wasm4.set_palette(3, @wasm4.rgb(0x484848))
  @wasm4.set_palette(4, @wasm4.rgb(0x000000))
  gs.load_settings()
  music.sound_on = true
  music.music_on = true
}
