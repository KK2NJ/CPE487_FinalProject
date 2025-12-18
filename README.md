# 3D Graphics Rendering Engine
### This project generates a 2D raster image from a 3D object. Our object is a cube which is rotated continously, and wireframe display of the cube is rendered.
## Making the cube
Any point can be definied in 3d space using 3 coordinates (x,y,z). 
A surface can then defined using 3 non colinear points. 
For a cube, it has 6 square surfaces. Each square surface requires 2 triangular surfaces to create. Creating a total of 12 faces. 
In our graphics package we created custom datastructures for these.
<img width="690" height="537" alt="image" src="https://github.com/user-attachments/assets/d1388e2d-21b5-497c-b1b9-eeb87746999e" />
The advantage of using a package here is that these datastructures are universally defined for all entities to use, while keeping the main clean.

To access these triangles throughout the code mesh_ROM.vhd was created, where the cube data is instanced and functions as an accesser by index. 

## Rotation
Rotation can be achieved using a rotational matrix. Rotational matricies are predifined set of matrix functions that be used to rotate a point around any given axis by any angle theta.
<img width="682" height="137" alt="image" src="https://github.com/user-attachments/assets/3b3b12a2-19bb-4d4f-9ac2-813fd2b26f2a" />
We defined another custom datatype, matrix4x4. Similar to mesh_ROM that was used to instnace our cube data, the rotation_matrix_gen entity is used to hold the rotation matricies above. This entity takes in the angle theta and calculates the pitch and roll rotatinoal matricies (mat_rot_x and mat_rot_z). 
# Sine and Cosine
Sine and cosine are not natively supported in vhdl and there is no simple algebraic solution to these equations. Even in C++, sine and cosine functions are approxiamted using specialized alogrithims and lookup tables (albiet with much better pricision). Our trig_lut entity, holds a pregenerated array for a lookup table for sine and cosine we generated using excel.
In the Rotation Matrix Generator process sine and cosine are only updated in a process where a change in theta triggers, improving performance.

# Matrix Multiplication
Takeing the 4x4 rotational matrix we generated and multiplying it by the a 4x1 matrix of any given point coordinate returns the new rotated point coordinates. Matrix multiplication is the result of the sum of the dot product of each column in the 4x1 matrix (1D matrix is just a vector) (x,y,z) with each row. 
<img width="926" height="487" alt="image" src="https://github.com/user-attachments/assets/58091e89-3d7e-4a75-819a-26d6d040595a" />
This is handled in the matrix_vecotr_mult entity.
The matrix_vector_mult also functions for clipping points out of view of the camera using a the sign of the fourth dot product. This why with the vector it returns and boolean value to indicate whether that new vector is valid and should or shouldn't be rendered. 

## Projection
Now we can use our modified vector to project itself onto the camera view. A 2D visualization of projection is this. 
<img width="346" height="451" alt="image" src="https://github.com/user-attachments/assets/141b8853-117a-4723-aa4a-e49f0002f8e0" />
The difference is where are doing a 3d vector onto a 2d plane. For this we can again create a matrix and use matrix multiplication. This matrix below is the projection matrix which uses a scale factor S for POV adjustment. f is the distance of the far clipping plane and n is the near clipping plane. That function normalizes the y and z coordinates to a the range between them.
<img width="335" height="227" alt="image" src="https://github.com/user-attachments/assets/e1d5a971-516b-4f75-9a84-01852fe52e5d" />
<img width="608" height="212" alt="image" src="https://github.com/user-attachments/assets/8662bf44-1579-4c5b-bbb0-2007e41dd7e4" />

## Main State Machine
<img width="671" height="861" alt="RenderingFSM drawio" src="https://github.com/user-attachments/assets/5c8678fd-eb26-4cfc-aade-76b68c73da78" />



