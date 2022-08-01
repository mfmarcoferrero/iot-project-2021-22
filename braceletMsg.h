#ifndef BRACELET_H
#define BRACELET_H

//Random key list
static const char *KEYS[]={
	// key for the first couple of devices (nodes 1-2)
	"5eLsdrtz1NJSr2jaxhjf",
	"5eLsdrtz1NJSr2jaxhjf",
	 // key for the second couple of devices (nodes 3-4)
	"7dbzRbuFIZoej5OyYYB0",
	"7dbzRbuFIZoej5OyYYB0",
};

typedef nx_struct msg {
	nx_uint8_t type;
	nx_uint8_t userID;
	nx_uint8_t key[20];
	nx_uint8_t kin_status;
	nx_uint8_t x;
	nx_uint8_t y;
} msg_t;

typedef nx_struct sensor_msg {
	nx_uint8_t kin_status;
	nx_uint8_t x;
	nx_uint8_t y;
} sensor_msg_t;


// Type of message
#define PAIRING 1
#define CONFIRM_PAIRING 2
#define OPERATION 3
#define ALERT 4
// Kinematic status
#define STANDING 5
#define WALKING 6
#define RUNNING 7
#define FALLING 8
#define MISSING 9
// Bracelet role
#define PARENT 10
#define CHILD 11

enum{
AM_MY_MSG = 6,
};

#endif
