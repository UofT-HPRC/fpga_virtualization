#ifndef NET_ISO_DRIVER_H
#define NET_ISO_DRIVER_H

//Handler for the net iso module
//Note - the callbacks assume byte addressable notation
typedef struct
{
	unsigned int (*read_callback)(unsigned int);
	void (*write_callback)(unsigned int, unsigned int);
	unsigned int offset;
	unsigned int token_int_bits;
	unsigned int token_frac_bits;

} net_iso_handler;

//Functions for decoupler and verifier
void init_net_iso (net_iso_handler*, unsigned int (*)(unsigned int), void (*)(unsigned int, unsigned int), unsigned int, unsigned int, unsigned int);
void decouple_net_iso(net_iso_handler*);
void recouple_net_iso(net_iso_handler*);
unsigned int is_timed_out_net_iso(net_iso_handler*);
void reset_time_out_net_iso(net_iso_handler*);
unsigned int is_oversized_net_iso(net_iso_handler*);
void reset_oversize_net_iso(net_iso_handler*);
void set_init_token_net_iso(net_iso_handler*, unsigned int);
unsigned int get_init_token_net_iso(net_iso_handler*);
void set_percent_bw_net_iso(net_iso_handler*, float);
float get_percent_bw_net_iso(net_iso_handler*);

#endif /* NET_ISO_DRIVER_H */
