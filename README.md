# Ragdoll Follower <!-- omit from toc -->

Control a ragdoll with another ragdoll

## Table of Contents <!-- omit from toc -->

- [Description](#description)
  - [Features](#features)
  - [Rational](#rational)
  - [Remarks](#remarks)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)
- [Credits](#credits)

## Description

This adds the Ragdoll Follower `Posing` tool.

### Features

- **Controller/Follower structure**: A *follower*'s physics bones track its corresponding *controller*'s. Move the controller ragdoll around, and the follower will move with it
- **Constraints**: How a follower tracks a controller depends on the constraint type: *weld*, *elastic*, or *ball socket*
- **Selective bones**: Allow a *follower* to follow a subset of the *controller*'s bones
- **Save/dupe support**: Duplicate a follower/controller pair
- **Remapping support**: If Ragdoll Puppeteer is installed, this tool will use its remapping features to remap between models

### Rational

This tool came up as a way for me to adapt to the SMG4-style of animating: e.g. using a physgun to move a talking head. On the other hand, 

- It would be nice to have the physics engine drive the entire animation: e.g. moving the hands and the head at the same time.
- I want to save the physics animation as an animation file, to enable iteration, collaboration, or complex post-processing workflows.

The best way to achieve this is to have two ragdolls--a *controller* ragdoll and a *follower* ragdoll. The *follower* ragdoll is constrained (by welds, ball sockets, etc.) to the *controller* ragdoll. The user may animate the *controller* ragdoll.

### Remarks

- You can tune `phys_timescale` to control the follower's speed

## Disclaimer

This tool has been tested extensively in singleplayer for animation. Expect bugs and undefined behaviors if used in multiplayer, and report them to [the issue tracker](https://github.com/vlazed/ragdoll-follower/issues).

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
