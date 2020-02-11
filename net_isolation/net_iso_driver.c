#include "net_iso_driver.h"

//Initiailize a handler for the control isolation module
void init_net_iso (net_iso_handler* handle, unsigned int (*rd_fun)(unsigned int),void (*wr_fun)(unsigned int, unsigned int),unsigned int off, unsigned int int_bits, unsigned int frac)
{
	handle->read_callback = rd_fun;
	handle->write_callback = wr_fun;
	handle->offset = off;
	handle->token_int_bits = int_bits;
	handle->token_frac_bits = frac;

	return;
}

//Decouple the contol interface
void decouple_net_iso(net_iso_handler* handle)
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
void recouple_net_iso(net_iso_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x0);
}

//Check timeout condition
unsigned int is_timed_out_net_iso(net_iso_handler* handle)
{
	//Read the status
	unsigned int status = (*handle->read_callback)(handle->offset + 4);
	status &= 0x8; //bit 3
	status >>= 3;
	return status;
}

//Reset timeout condition
void reset_time_out_net_iso(net_iso_handler* handle)
{
	//read current register value
	unsigned int prev = (*handle->read_callback)(handle->offset + 4);
	prev &= ~(0x8);

	//Write to timeout clear bit
	(*handle->write_callback)(handle->offset + 4, prev);
}

//Check oversize error condition
unsigned int is_oversized_net_iso(net_iso_handler* handle)
{
	//Read the status
	unsigned int status = (*handle->read_callback)(handle->offset + 4);
	status &= 0x4; //bit 2
	status >>= 2;
	return status;
}

//Reset oversize error decoupling condition
void reset_oversize_net_iso(net_iso_handler* handle)
{
	//read current register value
	unsigned int prev = (*handle->read_callback)(handle->offset + 4);
	prev &= ~(0x4);

	//Write to oversize error clear bit
	(*handle->write_callback)(handle->offset + 4, prev);
}

//Set the initial amount of tokens
void set_init_token_net_iso(net_iso_handler* handle, unsigned int toks)
{
	//Write the token count
	(*handle->write_callback)(handle->offset + 8, toks);
}

//Get the initial amount of tokens setting
unsigned int get_init_token_net_iso(net_iso_handler* handle)
{
	//Read the init tokens setting
	return (*handle->read_callback)(handle->offset + 8);
}

//BW percentage as a fraction of clock cycles (not available bandwidth on link), expressed as decimal (e.g. 100% = 1.0)
void set_percent_bw_net_iso(net_iso_handler* handle, float frac)
{
	//Calculate fixed point representation
	unsigned int fixed = frac * (1 << handle->token_frac_bits);

	//Write the token count
	(*handle->write_callback)(handle->offset + 12, fixed);
}

//Get the BW percentage
float get_percent_bw_net_iso(net_iso_handler* handle)
{
	//Read the fixed point value
	unsigned int fixed = (*handle->read_callback)(handle->offset + 12);

	//Calcuate floating point
	return (float)fixed / (float)(1 << handle->token_frac_bits);
}







