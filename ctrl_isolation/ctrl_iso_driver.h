#ifndef CTRL_ISO_DRIVER_H
#define CTRL_ISO_DRIVER_H

//Handler for the ctrl iso module
//Note - the callbacks assume byte addressable notation
typedef struct
{
	unsigned int (*read_callback)(unsigned int);
	void (*write_callback)(unsigned int, unsigned int);
	unsigned int offset;

} ctrl_iso_handler;

//Functions for decoupler and verifier
void init_ctrl_iso (ctrl_iso_handler*, unsigned int (*)(unsigned int), void (*)(unsigned int, unsigned int), unsigned int);
void decouple_ctrl_iso(ctrl_iso_handler*);
void recouple_ctrl_iso(ctrl_iso_handler*);
unsigned int is_timed_out_ctrl_iso(ctrl_iso_handler*);
void reset_time_out_ctrl_iso(ctrl_iso_handler*);

#endif /* CTRL_ISO_DRIVER_H */
