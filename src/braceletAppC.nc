/**
 *  Configuration file for wiring of braceletC module to other common 
 *  components needed for proper functioning
 */

#include "braceletMsg.h"


configuration braceletAppC {}

implementation {

/****** COMPONENTS *****/
  components MainC, braceletC as App;
  
  //Timers
  components new TimerMilliC() as PairingTimer;
  components new TimerMilliC() as OperationTimer;
  components new TimerMilliC() as AlertTimer;
  
  //Sensor
  components new FakeSensorC();
  
  //Active Messages
  components ActiveMessageC;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  //Send and Receive interfaces
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  //Radio Control
  App.SplitControl -> ActiveMessageC;
  
  //Interfaces to access package fields
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.PacketAcknowledgements -> AMSenderC;
    
  //Timer interface
  App.PairingTimer -> PairingTimer;
  App.OperationTimer -> OperationTimer;
  App.AlertTimer -> AlertTimer;
  
  //Fake Sensor read
  App.Read -> FakeSensorC;
  
}

