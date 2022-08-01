#include <stdio.h>
#include <stdlib.h>

generic module FakeSensorP() {

	provides interface Read<sensor_msg_t>;
	uses interface Random;
	

} implementation {

	//***************** Boot interface ********************//
	command error_t Read.read(){
		//Function to perform a (fake) measurement

		sensor_msg_t msg;
		uint8_t rand_prob;
		
		//	Random genaration of (x,y) coordinates -> number in [0,100] interval
		msg.x = call Random.rand16()%100;
		msg.y = call Random.rand16()%100;
		
		//	Random generation of a possible state (STANDING, WALKING, RUNNING, FALLING)
		//	P(STANDING) = P(WALKING) = P(RUNNING) = 0.3
		//	P(FALLING) = 0.1
		rand_prob = call Random.rand16()%100;
		
		if (rand_prob < 30){
		msg.kin_status = STANDING;
		} else if (rand_prob >= 30 && rand_prob < 60) {
		msg.kin_status = WALKING;
		} else if (rand_prob >= 60 && rand_prob < 90) {
		msg.kin_status = RUNNING;
		} else {
		msg.kin_status = FALLING;
		}
		
		signal Read.readDone( SUCCESS, msg );
		return SUCCESS;
	}
}
