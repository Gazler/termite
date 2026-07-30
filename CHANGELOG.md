## [0.4.4] - 2026-07-30

### Features

- *(Termite.Screen)* Add sequences for enhanced_keyboard_* ([9e6cac0](https://github.com/gazler/breeze/commit/9e6cac0dfee382228d767c6c920424d4d983e5ad))
## [0.4.3] - 2026-07-09

### Features

- *(screen)* Add enhanced keyboard mode helpers ([4e1c13d](https://github.com/gazler/breeze/commit/4e1c13d389fba0544f2914fd2072f78bcc717a62))
- *(Termite.Terminal.Shell)* Support configurable signal subscriptions ([32c80e5](https://github.com/gazler/breeze/commit/32c80e5687538362be3d172b58863bb3c51c6e2c))

### Bug Fixes

- Elixir 1.20 type warnings ([c391cac](https://github.com/gazler/breeze/commit/c391cac1b55e463d9ffc00c2c84bfa750483ba1b))
## [0.4.2] - 2026-04-17

### Features

- *(Termite.Terminal.Shell)* Support OSC sequences ([21731b9](https://github.com/gazler/breeze/commit/21731b9e373243ab5ed75141e5fc7c3297e7a0a0))
## [0.4.1] - 2026-03-19

### Features

- *(Termite.Style)* Add open_code/1 function ([0144fa7](https://github.com/gazler/breeze/commit/0144fa75b1db476d395394129f1d9f98f6644684))
- *(Termite.Style)* Support hex colors ([06ec5d3](https://github.com/gazler/breeze/commit/06ec5d3446146bd8837427cda982580e77fb6101))

### Bug Fixes

- *(Termite.Terminal.Shell)* Support escape sequencies with ~ ([cffd30d](https://github.com/gazler/breeze/commit/cffd30dbe54dfbbaa13e686004429bd12657c8d7))
- *(Termite.Terminal)* Resize safely when :io is not available ([2eb125f](https://github.com/gazler/breeze/commit/2eb125fa2d1bf3775250997c5a962222758bade1))
- *(Termite.Terminal.Shell)* Support SIngle Shift 3 keys (F1-F20) ([6431dc5](https://github.com/gazler/breeze/commit/6431dc54c8cdeb97b012a7b8e16b9d7116673d08))
## [0.4.0] - 2026-02-09

### Features

- *(Termite.Terminal.Shell)* Use newlines with carriage returns ([449ae11](https://github.com/gazler/breeze/commit/449ae11089a5d0bc2c850825f408b9f44ddc0b0f))
- *(Termite.Terminal)* Default to Shell adapter for OTP-28 ([516fbff](https://github.com/gazler/breeze/commit/516fbffd7886c54f761ec6e192d93274ffe80052))
## [0.3.1] - 2025-11-10

### Features

- *(Termite.Terminal.PrimTTY)* Vendor erlang records ([029d4ac](https://github.com/gazler/breeze/commit/029d4accc5696a80cda61f28b7b5426997abae21))
## [0.3.0] - 2025-05-08

### Features

- *(Termite.Terminal)* Add a resize callback ([d27a1a2](https://github.com/gazler/breeze/commit/d27a1a2ecd115084a51c13a83d93e8ff67674c6e))
- *(Termite.Screen)* Add functions for escape sequences ([61237e1](https://github.com/gazler/breeze/commit/61237e13caac71f5275b0913f388092c86963165))
- *(Termite.Screen)* Add delete_chars function ([b209c51](https://github.com/gazler/breeze/commit/b209c51168c1be1a827b6e8a87ce75fbb05af0c3))

### Bug Fixes

- *(examples)* Remove `:reset` escape sequence ([8ca63cb](https://github.com/gazler/breeze/commit/8ca63cb3f0139e15d685257e8167b7cdd9223c2f))

### Refactor

- *(examples/colors)* Extract color_block into a function ([2902c6c](https://github.com/gazler/breeze/commit/2902c6c7ca2ad3e0db0c941b91d45963f84d3df0))
## [0.2.0] - 2024-08-03

### Features

- *(prim_tty)* Make writes synchronous ([3bce459](https://github.com/gazler/breeze/commit/3bce4596bdf0dfef4933b96ad500a96d47619ab2))
## [0.1.0] - 2024-06-13
