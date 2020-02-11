//Handler for the ctrl iso module
typedef struct
{
	unsigned int (*read_callback)(unsigned int);
	void (*write_callback)(unsigned int, unsigned int);
	unsigned int offset;

} ctrl_iso_handler;

//Functions for decoupler and verifier
void init_ctrl_iso (ctrl_iso_handler*, unsigned int (*)(unsigned int), void (*)(unsigned int, unsigned int), unsigned int);
void decouple(ctrl_iso_hanlder*);
void recouple(ctrl_iso_hanlder*);
unsigned int is_timed_out(ctrl_iso_hanlder*);
void reset_time_out(ctrl_iso_hanlder*);
