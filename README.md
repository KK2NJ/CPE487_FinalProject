# CPE 487 Final Project - 3D Wireframe Rendering Engine for Platonic Solids
**By: Karan Kapoor and Mason Brewer**

## Project Overview 
The goal of this project is to have different types of platonic solids rotating around certain axis. 

# Types of Platonic Solids
<img width="500" height="408" alt="Platonic_Solids_Transparent svg" src="https://github.com/user-attachments/assets/81fc0a8a-7815-41ac-bb00-8490dfba3f0b" />

Ordered from left to right
Regular Tetrahedron, Cube, Regular Octahedron, Regular Dodecahedron, and Regular Icosahedron

# Video of Rotating Solids

https://github.com/user-attachments/assets/f95fe228-66aa-4ba5-b639-8f1a5cd01082


## Required Hardware / Attachments

**Board:** Digilent Nexys A7 (or equivalent FPGA board used in class)  
**Display:** VGA monitor (expects 800×600 @ 60 Hz timing from `vga_sync.vhd`)  
**Connections:**
- VGA cable from Nexys to the monitor
- USB cable for power/programming
- HDMI Cable to connect VGA cable
**Pins/IO:** All FPGA ↔ VGA and button pin mappings are handled in `constraints.xdc`.

## Creation of Solids
Any point can be definied in 3d space using 3 coordinates (x,y,z). 
A surface can then defined using 3 non colinear points. 
For a cube, it has 6 square surfaces. Each square surface requires 2 triangular surfaces to create. Creating a total of 12 faces. 
In our graphics package we created custom datastructures for these.
<img width="690" height="537" alt="image" src="https://github.com/user-attachments/assets/d1388e2d-21b5-497c-b1b9-eeb87746999e" />
The advantage of using a package here is that these datastructures are universally defined for all entities to use, while keeping the main clean.

# File Hierarchy
<img width="536" height="252" alt="Screenshot 2025-12-17 232814" src="https://github.com/user-attachments/assets/741ac360-c12e-457b-b295-976fc2be7c47" />

## Responsibilities 

### Karan Kapoor
- Edited and created graphics_pkg.vhd, constraints_3.xdc, engine_3d.vhd, and trig_LUT.vhd
- Edited platonic_rom.vhd
- Contributed to GitHub repository

### Mason Brewer
- Edited graphics_pkg.vhd, constraints_3.xdc, engine_3d.vhd, and trig_LUT.vhd
- Edited Main FSM and added Bresenham Line Algorithm
- Contributed to GitHub repository

## Setup
Download the following files from the repository to your computer:

Once you have downloaded the files, follow these steps:
1. Open **AMD Vivado™ Design Suite** and create a new RTL project called platonic_solids in Vivado Quick Start
2. In the "Add Sources" section, click on "Add Files" and add all of the `.vhd` files from this repository
3. In the "Add Constraints" section, click on "Add Files" and add the `.xdc` file from this repository
4. In the "Default Part" section, click on "Boards" and find and choose the Neyxs A7-100T board
5. Click "Finish" in the New Project Summary page
6. Run Synthesis
7. Run Implementation
8. Generate Bitstream
9. Connect the Nexys A7-100T board to the computer using the Micro USB cable and switch the power ON
10. Connect the VGA cable from the Nexys A7-100T board to the VGA monitor
11. Open Hardware Manager  
     - "Open Target"
     - "Auto Connect"
     - "Program Device"
12. Program should appear on the screen
3
