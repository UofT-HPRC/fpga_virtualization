#include "ctrl_iso_driver.h"

//Initiailize a handler for the control isolation module
void init_ctrl_iso (ctrl_iso_handler* handle, unsigned int (*rd_fun)(unsigned int),void (*wr_fun)(unsigned int, unsigned int),unsigned int off)
{
	handle->read_callback = rd_fun;
	handle->write_callback = wr_fun;
	handle->offset = off;

	return;
}

//Decouple the contol interface
void decouple_ctrl_iso(ctrl_iso_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x1);
	
	//Read decouple done until done
	unsigned int done = 0;
	do {
		done = (*handle->read_callback)(handle->offset + 0);
		done &= 0x2; //bit 1
	} while(!done);

	return;
}

//Disable the decoupling
void recouple_ctrl_iso(ctrl_iso_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x0);
}

//Check timeout condition
unsigned int is_timed_out_ctrl_iso(ctrl_iso_handler* handle)
{
	//Read the status
	unsigned int status = (*handle->read_callback)(handle->offset + 4);
	status &= 0x2; //bit 1
	status >>= 1;
	return status;
}

//Reset timeout condition
void reset_time_out_ctrl_iso(ctrl_iso_handler* handle)
{
	//Write to timeout clear bit
	(*handle->write_callback)(handle->offset + 4, 0x0);
}
