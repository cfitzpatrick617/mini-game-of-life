# Conway's Mini Game of Life

John Conway's famous zero player game - recreated in Godot Engine.

## How to Play

The Game of Life starts with an initial pattern of cells created by you - this is known as the seed. 

Each cell has a total of 8 neighbours. Cells evolve over time through an infinite series of steps known as generations. During each generation, cells are checked against a set of rules to see whether they should live or die.

<img width="150" alt="neighbours" src="https://github.com/user-attachments/assets/3e955161-d144-46a4-8446-d74c56356e82">

For Live Cells:
* < 2 live neighbours - death!
* 2 or 3 live neighbours - survival!
* \> 3 live neighbours - death!

For Dead Cells:
* 2 or 3 live neighbours - comes to life!


## Creative Controls

Creative controls allow you to edit the initial seed. Creative controls cannot be used whilst a simulation is in progress.

### Pen Button

Enters drawing mode.

![pen_icon](https://github.com/user-attachments/assets/f8342a23-99c2-4d59-8ee9-418603840290)


### Eraser Button

Enters erasing mode. 

![rubber_icon](https://github.com/user-attachments/assets/362ab7dd-bdd8-4948-a1c3-db29a313b5ef)

Alternatively, erase cells by right clicking in drawing mode.

### Clear Button

Clears the screen.

![clear_icon](https://github.com/user-attachments/assets/2892fc91-8760-4ee2-8f15-47ef916364e7)

## Simulation Controls

### Play / Pause Button

Plays and pauses the simulation. 

![play_icon](https://github.com/user-attachments/assets/ce2a82bd-1195-4e3c-bc1f-d7e8bd5493a6) 
![pause-icon](https://github.com/user-attachments/assets/160abb63-3f5c-4105-9114-b7dc1d9b76c6)

Alternatively, press "P" to play and pause the simulation.

### Reset Button

![kill_icon](https://github.com/user-attachments/assets/f2c18550-93db-44c7-8588-fcbb7361ed32)

Resets to the initial seed.


  

 
