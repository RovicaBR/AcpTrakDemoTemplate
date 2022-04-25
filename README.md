# AcpTrakDemoTemplate

## Table of Contents
* [Introduction](#Introduction)
* [Requirements](#Requirements)
* [How To Use](#How-To-Use)

<a name="Introduction"></a>
## Introduction
This is an ACOPOStrak demo project template developed by B&R Spain. The aim of this project is to reduce the time that is needed to develop a first project viability study.

The project contains some tasks that can be easily adapted to fit almost any initial setup. Based on our previous experience developing customized demo simulations, we classified the tasks in 2 different groups.

* **Single shuttle operations:** The shuttles will be operated individually (one product each shuttle). There are 3 available tasks depending on how many shuttles should be processed simultaneously.

<img src="https://user-images.githubusercontent.com/75721256/164710478-90081425-3dea-41ff-a0dc-0b312ed409bd.png" alt="drawing" style="width:400px;"/>

Of course, the different type of tasks could be combined such as:

<img src="https://user-images.githubusercontent.com/75721256/164711783-5117ac20-48ff-4183-9751-b03c63cefb92.png" alt="drawing" style="width:600px;"/>

* **Paired shuttle operations:** The shuttles will be operated in pairs (one product carried between two shuttles).   

Before any process can take place, the synch between two shuttles (ProcSync) must take place. After that, depending on how many products should be processed at the same time, the different tasks can be combined accordingly. 

<img src="https://user-images.githubusercontent.com/75721256/164710939-2ef5bcee-3773-4fad-a3a8-ca6a161ec132.png" alt="drawing" style="width:450px;"/>

A possible layout configuration could be arranged such as:

<img src="https://user-images.githubusercontent.com/75721256/165051008-f54cd00a-794b-426f-a879-397a83235dd0.png" alt="drawing" style="width:600px;"/>

<a name="Requirements"></a>
## Requirements

**IMPORTANT!** In order to use this template, the user should be familiar with the ACOPOStrak configuration and programming.

The project has been tested with the following versions:

* Automation Studio 4.10
* Scene Viewer 4
* mappView / mappMotion / mappControl (version 5.18)
* AR G4.90

<a name="How-To-Use"></a>
## How To Use

#### 1. Open AS project and adapt the existing ACOPOStrak layout.

From the Physical View, change the layout adding or deleting as many ACOPOStrak segments as needed. The Global.var file should also be modified accordingly.    

#### 2. Change the layout configuration from the .assembly file.

After the layout has been defined, the **.assembly**, **.sector** and **.processpointlist** files should be adapted as well.

#### 3. Make sure that the "DataTrak" folder exists on your PC.   

<img src="https://user-images.githubusercontent.com/75721256/165055779-4138b30d-33bb-4195-88b5-232d6d5cb84c.png" alt="drawing" style="width:500px;"/>

#### 4. Add as many tasks as needed in your "ProcessMachine" folder from the Logical View. 

Depending on how your product will be carried (between one or two shuttles), use the tasks inside the "SingleSh" or "PairedSh" folders. Notice that in the task header it is indicated if the task should be always included (mandatory) in your simulation or not. 

#### 5. Change the configuration parameters from each task.

Each task has its own configuration parameters in the **_INIT** subroutine.

They will need to be changed or adapted according for each task.

* **PPAdr**: Process point of the actual station.
* **SecAdr**: Sector of the actual station.
* **PPDest**: Process point of the next station.
* **SecDest**: Sector of the next station.
* **Speed_IN**: Entry station speed. (Should be the same as the output station speed from the previous station).
* **Acc_IN**: Entry station acceleration. (Should be the same as the output station acceleration from the previous station).
* **Speed_OUT**: Output station speed. 
* **Acc_OUT**: Output station acceleration.
* **WaitTime**: Station waitting time in ms.
* **DistTravelled/1/2**: Stopping distance (from the processpoint) for each shuttle.
* **ReleaseSts**: Defines if the station is a "release station". If it is, the output production in ppm will be increased by this station.
* **Red,Green,Blue**: RBG shuttle color configuration (from 0 to 1) after the process is completed. 

Example:

<img src="https://user-images.githubusercontent.com/75721256/165058980-fd937d33-c51e-439c-aef1-e8bee65ee1c3.png" alt="drawing" style="width:700px;"/>

#### 6. Perform an "Offline Installation".
After all the tasks are correctly configured and added to the software configuration, the project can be transfered to ArSim using an offline installation.

#### 7. Open the automatically generated .scn file with SceneViewer.
After the file is opened, establish communication via OPC UA.

#### 8. Open the mappView HMI
Access the HMI via http://127.0.0.1:81/index.html?visuId=Visu. Through the user interface, you will be able define several parameters from the simulation.

