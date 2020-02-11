#ifndef CLK_RST_DEC_DRIVER_H
#define CLK_RST_DEC_DRIVER_H

//Handler for the clock reset decoupler module
//Note - the callbacks assume byte addressable notation
typedef struct
{
	unsigned int (*read_callback)(unsigned int);
	void (*write_callback)(unsigned int, unsigned int);
	unsigned int offset;

} clock_reset_decoupler_handler;

//Functions for clock decoupling and asserting reset
void init_clock_reset_decoupler (clock_reset_decoupler_handler*, unsigned int (*)(unsigned int), void (*)(unsigned int, unsigned int), unsigned int);
void decouple_clock_crd(clock_reset_decoupler_handler*);
void recouple_clock_crd(clock_reset_decoupler_handler*);
void assert_reset_crd(clock_reset_decoupler_handler*);
void deassert_reset_crd(clock_reset_decoupler_handler*);

#endif /* CLK_RST_DEC_DRIVER_H */
