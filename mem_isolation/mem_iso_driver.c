#include "mem_iso_driver.h"

//Initiailize a handler for the control isolation module
void init_mem_iso (mem_iso_handler* handle, unsigned int (*rd_fun)(unsigned int),void (*wr_fun)(unsigned int, unsigned int),unsigned int off, unsigned int int_bits, unsigned int frac)
{
	handle->read_callback = rd_fun;
	handle->write_callback = wr_fun;
	handle->offset = off;
	handle->token_int_bits = int_bits;
	handle->token_frac_bits = frac;

	return;
}

//Decouple the contol interface
void decouple_mem_iso(mem_iso_handler* handle)
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
void recouple_mem_iso(mem_iso_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x0);
}

//Check timeout condition
unsigned int is_timed_out_mem_iso(mem_iso_handler* handle)
{
	//Read the status
	unsigned int status = (*handle->read_callback)(handle->offset + 4);
	status &= 0x2; //bit 1
	status >>= 3;
	return status;
}

//Reset timeout condition
void reset_time_out_mem_iso(mem_iso_handler* handle)
{
	//Write to timeout clear bit
	(*handle->write_callback)(handle->offset + 4, 0x0);
}

//Set the initial amount of tokens
void set_init_token_mem_iso(mem_iso_handler* handle, unsigned int toks)
{
	//Write the token count
	(*handle->write_callback)(handle->offset + 8, toks);
}

//Get the initial amount of tokens setting
unsigned int get_init_token_mem_iso(mem_iso_handler* handle)
{
	//Read the init tokens setting
	return (*handle->read_callback)(handle->offset + 8);
}

//BW percentage as a fraction of clock cycles (not available bandwidth on link), expressed as decimal (e.g. 100% = 1.0)
void set_percent_bw_mem_iso(mem_iso_handler* handle, float frac)
{
	//Calculate fixed point representation
	unsigned int fixed = frac * (1 << handle->token_frac_bits);

	//Write the token count
	(*handle->write_callback)(handle->offset + 12, fixed);
}

//Get the BW percentage
float get_percent_bw_mem_iso(mem_iso_handler* handle)
{
	//Read the fixed point value
	unsigned int fixed = (*handle->read_callback)(handle->offset + 12);

	//Calcuate floating point
	return (float)fixed / (float)(1 << handle->token_frac_bits);
}



//Set the initial amount of tokens
void set_init_aw_token_mem_iso(mem_iso_handler* handle, unsigned int toks)
{
	//Write the token count
	(*handle->write_callback)(handle->offset + 8, toks);
}

//Get the initial amount of tokens setting
unsigned int get_aw_init_token_mem_iso(mem_iso_handler* handle)
{
	//Read the init tokens setting
	return (*handle->read_callback)(handle->offset + 8);
}

//BW percentage as a fraction of clock cycles (not available bandwidth on link), expressed as decimal (e.g. 100% = 1.0)
void set_aw_percent_bw_mem_iso(mem_iso_handler* handle, float frac)
{
	//Calculate fixed point representation
	unsigned int fixed = frac * (1 << handle->token_frac_bits);

	//Write the token count
	(*handle->write_callback)(handle->offset + 12, fixed);
}

//Get the BW percentage
float get_aw_percent_bw_mem_iso(mem_iso_handler* handle)
{
	//Read the fixed point value
	unsigned int fixed = (*handle->read_callback)(handle->offset + 12);

	//Calcuate floating point
	return (float)fixed / (float)(1 << handle->token_frac_bits);
}



//Set the initial amount of tokens
void set_init_ar_token_mem_iso(mem_iso_handler* handle, unsigned int toks)
{
	//Write the token count
	(*handle->write_callback)(handle->offset + 16, toks);
}

//Get the initial amount of tokens setting
unsigned int get_init_ar_token_mem_iso(mem_iso_handler* handle)
{
	//Read the init tokens setting
	return (*handle->read_callback)(handle->offset + 16);
}

//BW percentage as a fraction of clock cycles (not available bandwidth on link), expressed as decimal (e.g. 100% = 1.0)
void set_ar_percent_bw_mem_iso(mem_iso_handler* handle, float frac)
{
	//Calculate fixed point representation
	unsigned int fixed = frac * (1 << handle->token_frac_bits);

	//Write the token count
	(*handle->write_callback)(handle->offset + 20, fixed);
}

//Get the BW percentage
float get_ar_percent_bw_mem_iso(mem_iso_handler* handle)
{
	//Read the fixed point value
	unsigned int fixed = (*handle->read_callback)(handle->offset + 20);

	//Calcuate floating point
	return (float)fixed / (float)(1 << handle->token_frac_bits);
}







