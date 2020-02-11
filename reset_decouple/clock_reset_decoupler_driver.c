#include "clock_reset_decoupler_driver.h"

//Initiailize a handler for the clock reset decoupler isolation module
void init_clock_reset_decoupler (clock_reset_decoupler_handler* handle, unsigned int (*rd_fun)(unsigned int),void (*wr_fun)(unsigned int, unsigned int),unsigned int off)
{
	handle->read_callback = rd_fun;
	handle->write_callback = wr_fun;
	handle->offset = off;

	return;
}

//Decouple the clock interface
void decouple_clock_crd(clock_reset_decoupler_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x1);
}

//Disable the clock decoupling
void recouple_clock_crd(clock_reset_decoupler_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 0, 0x0);
}

//Assert the reset for the application
void assert_reset_crd(clock_reset_decoupler_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 4, 0x1);
}

//Deassert the reset for the application
void deassert_reset_crd(clock_reset_decoupler_handler* handle)
{
	//Write to decouple bit
	(*handle->write_callback)(handle->offset + 4, 0x0);
}









