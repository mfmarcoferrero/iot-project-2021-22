/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response (same for sensors 3 and 4).
 *  The reply message contains a reading from the Fake Sensor.
 *	
 */

#include "braceletMsg.h"
#include "Timer.h"

module braceletC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
    interface SplitControl;
    interface Packet;
    interface AMSend;
    interface Receive;
    interface AMPacket;
    
	//interface for timer to menage the 3 phases:
	//PAIRING, OPERATION and ALERT
	interface Timer<TMilli> as PairingTimer;
    interface Timer<TMilli> as OperationTimer;
    interface Timer<TMilli> as AlertTimer;
    
    //other interfaces, if needed
    interface PacketAcknowledgements;
	
	//interface used to perform sensor reading (to get the value from a sensor)
    interface Read<sensor_msg_t>;

  }

} implementation {

  uint8_t role;
  uint8_t paired_id;
  sensor_msg_t last_status;
  message_t packet;


  void sendPairingReq();
  void sendPairingResp(uint8_t destID);
  void sendSensorStatus();
  void printKinStatus(uint8_t status);
  void throwAlarm(uint8_t status);
  
  
  //***************** Boot interface ********************//
  event void Boot.booted() {
  	dbg_clear("boot", "\n----------------------------------------------------\n");
  	dbg_clear("boot", "----------------------------------------------------\n");
	dbg_clear("boot", "\tApplication BOOTED on NODE %u.\n", TOS_NODE_ID);
	dbg_clear("boot", "----------------------------------------------------\n");
	dbg_clear("boot", "----------------------------------------------------\n\n");
    call SplitControl.start();
  }

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    if (err == SUCCESS)
    {
      dbg("radio", "Radio on!\n\n\n");
      call PairingTimer.startPeriodic(1000);
    }
    else
    {
      // If NOT turning on the Radio -> restart
      call SplitControl.start();
    }
  }
  
  event void SplitControl.stopDone(error_t err){
    dbg("radio", "Turning OFF node: %u", TOS_NODE_ID);
  }

  //***************** PairingTimer interface ********************//
  // Pairing phase:
  // 1. Parent and child broadcast their unique 20-char random key (preloaded at production time)
  // 2. When a matching key is received, a confirmation message is sent in unicast to the "possible" paired device
  // 3. When the confirmation message is ACKed devices are paired
  // First device of the couple is always the PARENT, second one is always a CHILD
  event void PairingTimer.fired() {
	/* This event is triggered every time the timer fires (every second a new pairing request is sent).
	 * When the timer fires, we send a new pairing request
	 */
	  dbg("pairing_timer", "-> PAIRING TIMER fired at %s.\n", sim_time_string());
      sendPairingReq();
  }
  
    //***************** Send pairing request function ********************//
  void sendPairingReq() {
  	 //Create a pointer to the payload of the packet to send
  	 msg_t* msg = (msg_t*)(call Packet.getPayload(&packet, sizeof(msg_t)));
	 if (msg == NULL) {
		return;
	 }
	 // Create a new message of type PAIRING with userID and pairing_key in the payload
	 msg -> type = PAIRING;
	 msg -> userID = TOS_NODE_ID;
	 strcpy(msg -> key, KEYS[TOS_NODE_ID-1]);
	 dbg_clear("radio_pairing","\t\tSENDING PAIRING PACKET from node: %u ... \n", msg -> userID);
	 if(call AMSend.send(AM_BROADCAST_ADDR, &packet,sizeof(msg_t)) == SUCCESS){
	 	
	 	dbg_clear("radio_pairing", "\t\tpairing_key: %s \n", msg -> key);
	 	
	 }
  }        

  //****************** Send response to a Pairing request *****************//
  void sendPairingResp(uint8_t destID) {
  	 //Create a pointer to the payload of the packet to send
  	 msg_t* msg = (msg_t*)(call Packet.getPayload(&packet, sizeof(msg_t)));
	 if (msg == NULL) {
		return;
	 }
	 // Create a new message of type PAIRING with userID and pairing_key in the payload
	 msg -> type = CONFIRM_PAIRING;
	 msg -> userID = TOS_NODE_ID;
	 strcpy(msg -> key, KEYS[TOS_NODE_ID-1]);
	 //Send a confirmation packet with the ack mode
	 call PacketAcknowledgements.requestAck(&packet);
	 dbg_clear("radio_pairing","\t\tSENDING CONFIRMATION PAIRING PACKET from node %u to node %u ... \n", msg -> userID, destID);
	 if(call AMSend.send(destID, &packet,sizeof(msg_t)) == SUCCESS){

	 	dbg_clear("radio_pairing", "\t\t PAIRING CONFIRMATION SENT\n");
	 	
	 }
  }
  
  //***************** OperationTimer interface ********************//
  event void OperationTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a new pairing request
	 */
	  dbg("operation_timer", "-> OPERATION TIMER fired at %s.\n", sim_time_string());
      call Read.read();
  }
  
  //*************** Read interface for FakeSensor ****************//
  event void Read.readDone(error_t result, sensor_msg_t msg) {
	last_status = msg;
	dbg_clear("radio_pack", "\t\tNew SENSOR READ\n");
	printKinStatus(msg.kin_status);
  	dbg_clear("radio_pack", "\t\t||Position:\tX: %u Y: %u\n\n", msg.x, msg.y);
    sendSensorStatus();
  }
  
  //*************** Function to send  ****************//
  void sendSensorStatus() {

  	 //Create a pointer to the payload of the packet to send
  	 msg_t* msg = (msg_t*)(call Packet.getPayload(&packet, sizeof(msg_t)));
	 if (msg == NULL) {
		return;
	 }
	 // Create a new message of type OPERATION with userID, kinematic status and coordinates in the payload
	 msg -> type = OPERATION;
	 msg -> userID = TOS_NODE_ID;
	 msg -> kin_status = last_status.kin_status;
	 msg -> x = last_status.x;
	 msg -> y = last_status.y;
	 dbg_clear("radio_operation","\t\tSENDING SENSOR STATUS PACKET to node: %u ... \n", paired_id);

	 //Send a sensor packet with the ack mode
	 call PacketAcknowledgements.requestAck(&packet);
	 if(call AMSend.send(paired_id, &packet,sizeof(msg_t)) == SUCCESS){
	 	
	 	//printKinStatus(msg -> kin_status);
    	dbg_clear("radio_operation", "\t\tSENT\n\n");
	 	
	 }
  }   
  
  
  //***************** AlertTimer interface ********************//
  event void AlertTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a new pairing request
	 */
	  dbg("alert_timer", "-> ALERT TIMER fired at %s.\n", sim_time_string());
	  throwAlarm(MISSING);
	  call AlertTimer.startOneShot(60000);
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	if (&packet == buf && err == SUCCESS) {
      msg_t* msg = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));
      dbg("radio_pack", "-> PACKET SEND DONE at %s\n", sim_time_string());
      
      switch (msg -> type) {
    		case PAIRING:
    			dbg_clear("radio_pairing","\t\tPAIRING messages sent\n\n");
    			break;
    		case CONFIRM_PAIRING:
    		
    			if (call PacketAcknowledgements.wasAcked(buf)) {
		    		call PairingTimer.stop();
		    		dbg_clear("radio_ack", "\t\tPAIRING-ACK received at time %s\n", sim_time_string()); 
		    
					// Role decision
					if (TOS_NODE_ID == 1 || TOS_NODE_ID == 3){
					  // Parent bracelet
					  role = PARENT;
					  paired_id = TOS_NODE_ID + 1;
					  dbg_clear("radio_pairing","\t\tPARENT BRACELET\n");
					  dbg_clear("radio_pairing","\t\tListening mode ON\n");
					  call AlertTimer.startOneShot(60000); // One alert message each 60 seconds
					} else {
					  // Child bracelet
					  role = CHILD;
					  paired_id = TOS_NODE_ID - 1;
					  dbg_clear("radio_pairing","\t\tCHILD BRACELET\n");
					  dbg_clear("radio_pairing","\t\tSending mode ON\n");
					  call OperationTimer.startPeriodic(10000); // One sensor message each 10 seconds
					}
					dbg_clear("radio_pairing", "\n-------------------------------------------------------");
					dbg_clear("radio_pairing", "\n------------------ DEVICES CONNECTED ------------------");
					dbg_clear("radio_pairing", "\n-------------------------------------------------------\n\n");
				
			  	} else {
			  	    dbg_clear("radio_ack", "\t\tPAIRING-ACK not received\n\n");
					// RESend confirmation 
					if (TOS_NODE_ID == 1 || TOS_NODE_ID == 3){
					  sendPairingResp(TOS_NODE_ID + 1);
					} else {
					  sendPairingResp(TOS_NODE_ID - 1);
					}
			  	}
			  	
    			break;
    		
    		case OPERATION: 
    			if (call PacketAcknowledgements.wasAcked(buf)){
    				//Sending process OK
					dbg_clear("radio_ack", "\t\tSTATUS-ACK received\n\n");
				} else {
					dbg_clear("radio_ack", "\t\tSTATUS-ACK not received \n\n");
					dbg_clear("radio_ack", "\t\tRESEND last sensor read \n\n");
					sendSensorStatus(); //RESend sensor msg
				}
      	
    			break;
    		
    		case ALERT:
    		
    			break;
    	}
    }
  }

  //************************ Receive interface ***********************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	if (len != sizeof(msg_t)) {
      return buf;
    }
    else {
    	msg_t *msg = (msg_t *)payload;
    	dbg("radio_pack", "-> RECEIVED PACKET at time %s\n", sim_time_string());
    	switch (msg -> type) {
    		case PAIRING:
    			dbg_clear("radio_rec", "\t\tPAIRING packet \n");
    			dbg_clear("radio_rec", "\t\t key: %s \n", msg -> key);
    			if (strcmp(msg -> key, KEYS[TOS_NODE_ID-1]) == 0){
    				dbg_clear("radio_rec", "\t\tNode %u is a POSSIBLE pairing device \n", msg -> userID);
    				sendPairingResp(msg -> userID);

    			} else {
    			    dbg_clear("radio_rec", "\t\tNode %u is NOT a pairing device \n", msg -> userID);
    			}
    			break;
    		case CONFIRM_PAIRING:
    			dbg_clear("radio_rec", "\t\tPAIRING CONFIRMATION packet from node: %u\n", msg -> userID);
    			call PairingTimer.stop();
    			paired_id = msg -> userID;
    		 	// Role decision
    			// if parent remain in listen mode
				if (TOS_NODE_ID == 1 || TOS_NODE_ID == 3){
				  // Parent bracelet
				  dbg_clear("radio_pairing","\t\tPARENT BRACELET\n");
				  dbg_clear("radio_pairing","\t\tListening mode ON\n");
				  call AlertTimer.startOneShot(60000);
				} else {
				  // if child start sending mode
				  // Child bracelet
				  dbg_clear("radio_pairing","\t\tCHILD BRACELET\n");
				  dbg_clear("radio_pairing","\t\tSending mode ON\n");
				  call OperationTimer.startPeriodic(10000);
				}
    			
    			
    			break;
    		
    		case OPERATION:
    			if (role == PARENT){
    				call AlertTimer.stop();
    				call AlertTimer.startOneShot(60000); // One alert message each 60 seconds
    			}
    			last_status.kin_status = msg -> kin_status;
    			last_status.x = msg -> x;
    			last_status.y = msg -> y;
    			dbg_clear("radio_rec", "\t\tSTATUS packet RECEIVED from node: %u\n", msg -> userID);
    			if (msg -> kin_status == FALLING) {
    				throwAlarm(FALLING);
    			} else {
					printKinStatus(msg -> kin_status);
    			}
    			dbg_clear("radio_operation", "\t\t||Position:\tX: %u Y: %u\n", msg -> x, msg -> y);
	  			dbg_clear("radio_operation", "\n");
    			break;
    	}
    	
    	
    	return buf;
    
    }
    {
      dbgerror("radio_rec", "Receiving error \n");
    }
	
	
  }
  
  /***************** PRINT KIN STATUS ***********************/
  void printKinStatus(uint8_t status){
  	switch (status) {
  		case STANDING:
  			dbg_clear("radio_operation", "\n\t\t||Sensor status: STANDING\n");
  			break;
  		case WALKING:
  		  	dbg_clear("radio_operation", "\n\t\t||Sensor status: WALKING\n");
  			break;
  		case RUNNING:
  		  	dbg_clear("radio_operation", "\n\t\t||Sensor status: RUNNING\n");
  			break;
  		case FALLING:
  		  	dbg_clear("radio_operation", "\n\t\t||Sensor status: FALLING\n");
  			break;
  		case MISSING:
  			dbg_clear("radio_operation", "\n\t\t||Sensor status: MISSING\n");
  			break;
  	}
  	return;
  }
  
  /***************** SEND MISSING or FALLING alarm ***********************/
  void throwAlarm(uint8_t status){
  	dbg_clear("radio_alert", "\n\n\t\t !!!! A L E R T !!!!\n\n");
  	switch(status){
  		case MISSING:
  			dbg_clear("radio_alert", "\n\t\t||MISSING BRACELET\n");
  			dbg_clear("radio_alert", "\n\t\t||LAST STATUS RECEIVED: \n");
  			printKinStatus(last_status.kin_status);
  			dbg_clear("radio_alert", "\t\t||Position:\tX: %u Y: %u\n\n", last_status.x, last_status.y);
  		break;
  		case FALLING:
  			dbg_clear("radio_alert", "\n\t\t||CHILD IS FALLING\n");
  		break;
  	}
  
  }
  
}
