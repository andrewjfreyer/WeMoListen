WeMoListen
=======

**NOTE: This project is not maintained**

Perl Listener for [WeMo Devices](http://www.belkin.com/us/Products/home-automation/c/wemo-home-automation/)

* Designed around Perl UPnP
* Designed for [Raspberry Pi](http://www.raspberrypi.org/) with a cheap [Bluetooth Dongle](http://www.amazon.com/SANOXY%C2%AE-Bluetooth-Wireless-Adapter-eMachine/dp/B003VWU79I/ref=pd_sim_pc_1?ie=UTF8&refRID=16KWQH2VYRTN82GTNS70). 
* Operable to save & log WeMo data (*e.g.,* on/off, motion)
* Works with [PushOver](http://www.pushover.net) service for alerts & notifications

<h2>TL;DR</h2>

Monitor [WeMo](http://www.belkin.com/us/Products/home-automation/c/wemo-home-automation/) devices (*e.g.,* swithces, outlets, motion sensors, etc.) on a [Raspberry Pi](http://www.raspberrypi.org/) (or other server). 

<h2>Summary</h2>

  WeMoListen will subscribe to all notifications that are available, but is keyed for specific events such as state changes. 

<h2>Installation Instructions (Debian):</h2>

1. Install Perl UPnP Lib

2. Install Replace **common.pm** and **controlpoint.pm**
  