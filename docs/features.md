# Features Documentation

This document outlines the key features of our application.

## Feature 1: Game Object System

- **Description**: The game object system allows for the creation and management of game objects.
- **Usage**: Use the `GameObject` class to create and manage game objects.

## Feature 2: Scene Management

- **Description**: The scene management system allows for the creation and management of scenes.
- **Usage**: Use the `Scene` class to create and manage scenes.

## Feature 3: Cache Manager

- **Description**: The cache manager handles caching of spritesheets and other resources.
- **Usage**: Use the `cacheManager` to manage cached resources.

## Feature 4: Audio Management

- **Description**: The audio manager provides a centralized way to handle audio playback, including loading, playing, and managing sound effects and music.
- **Usage**: Use the `audioManager` to load and play audio files.

  ```lua
  -- Example usage of audioManager

  -- Load a sound effect
  local soundEffect = audioManager.loadSound("assets/sounds/boom.wav")

  -- Play the sound effect
  audioManager.playSound(soundEffect)

  -- Load background music
  local music = audioManager.loadMusic("assets/music/theme.mp3")

  -- Play the background music
  audioManager.playMusic(music)

  -- Stop the background music
  audioManager.stopMusic()
  ```

  The `audioManager` can programmatically create sounds and play them. It supports both sound effects and background music, allowing for flexible audio management in the game.

## Feature 5: Asset Export

- **Description**: Scenes can be rendered offscreen at exact pixel sizes and written as PNGs. Used for icons, covers and logos so marketing art follows the game's fonts and colours.
- **Usage**: Add an `assets` block to the `Game` config with `{ name, scene, width, height, postProcess?, transparent? }` items, where `scene` is a Scene constructor taking `(width, height)`. Run `love . --export-assets`.
