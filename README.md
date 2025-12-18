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

#### Inputs
- clk_in: 100 MHz system clock input from the Nexys A7.<br>
- btn0: Start/Pause control.
 When paused, the engine clears the framebuffer so the VGA output is black. When running, the engine renders the current solid each frame.
-btnl: Next solid (edge-detected press). Cycles through the Platonic solids in order (e.g., tetra → cube → octa → dodeca → icosa).
- btnr: Reset solid selection (edge-detected press). Returns to the tetrahedron.
#### Outputs
- VGA_red[3:0]: 4-bit red intensity to the VGA DAC.

- VGA_green[3:0]: 4-bit green intensity to the VGA DAC.

- VGA_blue[3:0]: 4-bit blue intensity to the VGA DAC.

- VGA_hsync: Horizontal sync signal for VGA timing (from vga_sync.vhd).

- VGA_vsync: Vertical sync signal for VGA timing (from vga_sync.vhd).

## Main State Machine from engine_3d.vhd
<img width="671" height="861" alt="RenderingFSM drawio" src="https://github.com/user-attachments/assets/5c8678fd-eb26-4cfc-aade-76b68c73da78" />


## Rotation (How the 3D shape spins)

The 3D rotation is performed inside `engine_3d.vhd` during the **CALC_EDGE** stage of the main finite state machine. For every edge of the current solid, the engine takes two 3D endpoints (`v0_3d` and `v1_3d`) from `platonic_rom`, rotates them in 3D space, then projects the rotated points to 2D framebuffer coordinates before drawing the line with Bresenham.

### Where rotation happens in the code
Rotation math is implemented in the FSM state:

- `when CALC_EDGE =>`

This state computes a rotated version of each endpoint using sine/cosine values from `trig_lut`.

### Z-axis rotation (spin in the XY plane)
For a 3D point `(x, y, z)`, Z rotation is applied first:

- `x' = x*cos(θ) - y*sin(θ)`
- `y' = x*sin(θ) + y*cos(θ)`
- `z' = z`

In VHDL this appears as:


xz0 := fixed_mult(v0_3d.x, cos_z) - fixed_mult(v0_3d.y, sin_z);<br>
yz0 := fixed_mult(v0_3d.x, sin_z) + fixed_mult(v0_3d.y, cos_z);<br>
zz0 := v0_3d.z;
<img width="682" height="137" alt="image" src="https://github.com/user-attachments/assets/3b3b12a2-19bb-4d4f-9ac2-813fd2b26f2a" />
# Sine and Cosine
Sine and cosine are not natively supported in vhdl and there is no simple algebraic solution to these equations. Even in C++, sine and cosine functions are approxiamted using specialized alogrithims and lookup tables (albiet with much better precision). Our trig_lut entity, holds a pregenerated array for a lookup table for sine and cosine we generated using excel.
In the Rotation Matrix Generator process sine and cosine are only updated in a process where a change in theta triggers, improving performance.



# Matrix Multiplication
Takeing the 4x4 rotational matrix we generated and multiplying it by the a 4x1 matrix of any given point coordinate returns the new rotated point coordinates. Matrix multiplication is the result of the sum of the dot product of each column in the 4x1 matrix (1D matrix is just a vector) (x,y,z) with each row. 
<img width="926" height="487" alt="image" src="https://github.com/user-attachments/assets/58091e89-3d7e-4a75-819a-26d6d040595a" />

## Projection
Now we can use our modified vector to project itself onto the camera view. A 2D visualization of projection is this. 
<img width="346" height="451" alt="image" src="https://github.com/user-attachments/assets/141b8853-117a-4723-aa4a-e49f0002f8e0" />
The difference is where are doing a 3d vector onto a 2d plane. For this we can again create a matrix and use matrix multiplication. This matrix below is the projection matrix which uses a scale factor S for POV adjustment. f is the distance of the far clipping plane and n is the near clipping plane. That function normalizes the y and z coordinates to a the range between them.
<img width="335" height="227" alt="image" src="https://github.com/user-attachments/assets/e1d5a971-516b-4f75-9a84-01852fe52e5d" />

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
### Difficulties
- Getting multiplication to properly work
- Understanding unique data types that could work in vhdl
- Changing floating point values to IEEE standards
- Getting values constrained to the memory we were constrained to on the board
- Understanding different software solutions that would work with the board e.g. BRAM vs On-the-fly Pixel math and CORDIC algorithm vs sin-cos-LUT
- Optimizing Matrix Multiplication with nested for loops
