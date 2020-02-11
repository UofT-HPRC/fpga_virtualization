#ifndef MEM_ISO_DRIVER_H
#define MEM_ISO_DRIVER_H

//Handler for the mem iso module
//Note - the callbacks assume byte addressable notation
typedef struct
{
	unsigned int (*read_callback)(unsigned int);
	void (*write_callback)(unsigned int, unsigned int);
	unsigned int offset;
	unsigned int token_int_bits;
	unsigned int token_frac_bits;

} mem_iso_handler;

//Functions for decoupler and verifier
void init_mem_iso (mem_iso_handler*, unsigned int (*)(unsigned int), void (*)(unsigned int, unsigned int), unsigned int, unsigned int, unsigned int);
void decouple_mem_iso(mem_iso_handler*);
void recouple_mem_iso(mem_iso_handler*);
unsigned int is_timed_out_mem_iso(mem_iso_handler*);
void reset_time_out_mem_iso(mem_iso_handler*);
void set_init_token_mem_iso(mem_iso_handler*, unsigned int);

//For unified BW throttler
unsigned int get_init_token_mem_iso(mem_iso_handler*);
void set_percent_bw_mem_iso(mem_iso_handler*, float);
float get_percent_bw_mem_iso(mem_iso_handler*);

//For seperated BW throttlers
void set_init_aw_token_mem_iso(mem_iso_handler*, unsigned int);
unsigned int get_aw_init_token_mem_iso(mem_iso_handler*);
void set_aw_percent_bw_mem_iso(mem_iso_handler*, float);
float get_aw_percent_bw_mem_iso(mem_iso_handler*);

void set_init_ar_token_mem_iso(mem_iso_handler*, unsigned int);
unsigned int get_init_ar_token_mem_iso(mem_iso_handler*);
void set_ar_percent_bw_mem_iso(mem_iso_handler*, float);
float get_ar_percent_bw_mem_iso(mem_iso_handler*);

#endif /* MEM_ISO_DRIVER_H */
