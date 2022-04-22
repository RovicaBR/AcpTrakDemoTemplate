# AcpTrakDemoTemplate

## Table of Contents
* [Introduction](#Introduction)
* [Requirements](#Requirements)
* [How To Use](#How-To-Use)

<a name="Introduction"></a>
## Introduction
This is an ACOPOStrak demo project template developed by B&R Spain. The aim of this project is to reduce the time that is needed to develop a first project viability study.

The project contains some tasks that can be easily adapted to fit almost any initial setup. Based on our previous experience developing customized demo simulations, we classified the tasks in 2 different groups.

* Single shuttle operations.

![image](https://user-images.githubusercontent.com/75721256/164710478-90081425-3dea-41ff-a0dc-0b312ed409bd.png)

* Paired shuttle operations.

<a name="Requirements"></a>
## Requirements
* Automation Studio 4.10
* Scene Viewer 4
* mappView / mappMotion / mappControl (version 5.18)
* AR ???

<a name="How-To-Use"></a>
## How To Use

#### 1. Open AS project and perform an "Offline Installation".
Make sure that the project has been transfered to ArSim using an offline installation.

#### 2. Open the file .scn found under the "Scene Viewer" folder in the Logical View
After the "AcpTrakViewer.scn" file is opened, establish communication via OPC UA.

#### 3. Open the mappView HMI
Access the HMI via http://127.0.0.1:81/index.html?visuId=Visu. Through the user interface, you will be able define several parameters from the simulation.

