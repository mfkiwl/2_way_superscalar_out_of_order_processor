#include "DirectC.h"
#include <curses.h>
#include <stdio.h>
#include <signal.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/signal.h>
#include <time.h>
#include <string.h>

#define PARENT_READ     readpipe[0]
#define CHILD_WRITE     readpipe[1]
#define CHILD_READ      writepipe[0]
#define PARENT_WRITE    writepipe[1]
#define PARENT_READ     0
#define CHILD_WRITE     1
#define CHILD_READ      2
#define PARENT_WRITE    3
#define NUM_HISTORY     256
#define NUM_PRF         48
#define NUM_STAGES      5
#define NOOP_INST       0x47ff041f
#define NUM_REG_GROUPS  11

// random variables/stuff
int fd[2], writepipe[2], readpipe[2];
int stdout_save;
int stdout_open;
void signal_handler_IO (int status);
int wait_flag=0;
char done_state;
char echo_data;
FILE *fp;
FILE *fp2;
int setup_registers = 0;
int stop_time;
int done_time = -1;
char time_wrapped = 0;

// Structs to hold information about each register/signal group
typedef struct win_info {
  int height;
  int width;
  int starty;
  int startx;
  int color;
} win_info_t;

typedef struct reg_group {
  WINDOW *reg_win;
  char ***reg_contents;
  char **reg_names;
  int num_regs;
  win_info_t reg_win_info;
} reg_group_t;

// Window pointers for ncurses windows
WINDOW *title_win;
WINDOW *comment_win;
WINDOW *time_win;
WINDOW *sim_time_win;
WINDOW *instr_win;
WINDOW *clock_win;
WINDOW *pc_win;
WINDOW *id_win;
WINDOW *rat_win;
WINDOW *prf_win;
WINDOW *prf_r_win;
WINDOW *rrat_win;
WINDOW *rob_win;
WINDOW *rs_win;
WINDOW *ex_win;
WINDOW *cdb_win;
WINDOW *wb_win;
WINDOW *misc_win;

// arrays for register contents and names
int history_num=0;
int num_misc_regs = 0;
int num_pc_regs = 0;
int num_id_regs = 0;
int num_rat_regs = 0;
int num_rrat_regs = 0;
int num_ex_regs = 0;
int num_cdb_regs = 0;
int num_prf_regs = 0;
int num_rob_regs = 0;
int num_wb_regs = 0;
int num_rs_regs = 0;
char readbuffer[1024];
char **timebuffer;
char **cycles;
char *clocks;
char *resets;
char **inst_contents;
char ***pc_contents;
char ***id_contents;
char ***rat_contents;
char ***prf_contents;
char ***rrat_contents;
char ***rob_contents;
char ***rs_contents;
char ***ex_contents;
char ***cdb_contents;
char ***wb_contents;
char ***misc_contents;
char ***prf_r_contents;
char **rs_reg_names;
char **pc_reg_names;
char **id_reg_names;
char **rrat_reg_names;
char **prf_reg_names;
char **ex_reg_names;
char **cdb_reg_names;
char **rat_reg_names;
char **rob_reg_names;
char **wb_reg_names;
char **misc_reg_names;

char *get_opcode_str(int inst, int valid_inst);
void parse_register(char* readbuf, int reg_num, char*** contents, char** reg_names);
int get_time();


// Helper function for ncurses gui setup
WINDOW *create_newwin(int height, int width, int starty, int startx, int color){
  WINDOW *local_win;
  local_win = newwin(height, width, starty, startx);
  wbkgd(local_win,COLOR_PAIR(color));
  wattron(local_win,COLOR_PAIR(color));
  box(local_win,0,0);
  wrefresh(local_win);
  return local_win;
}

// Function to draw positive edge or negative edge in clock window
void update_clock(char clock_val){
  static char cur_clock_val = 0;
  // Adding extra check on cycles because:
  //  - if the user, right at the beginning of the simulation, jumps to a new
  //    time right after a negative clock edge, the clock won't be drawn
  if((clock_val != cur_clock_val) || strncmp(cycles[history_num],"      0",7) == 1){
    mvwaddch(clock_win,3,7,ACS_VLINE | A_BOLD);
    if(clock_val == 1){

      //we have a posedge
      mvwaddch(clock_win,2,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_ULCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,4,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_LRCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    } else {

      //we have a negedge
      mvwaddch(clock_win,4,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_LLCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,2,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_URCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    }
  }
  cur_clock_val = clock_val;
  wrefresh(clock_win);
}

// Function to create and initialize the gui
// Color pairs are (foreground color, background color)
// If you don't like the dark backgrounds, a safe bet is to have
//   COLOR_BLUE/BLACK foreground and COLOR_WHITE background
void setup_gui(FILE *fp){
  initscr();
  if(has_colors()){
    start_color();
    init_pair(1,COLOR_CYAN,COLOR_BLACK);    // shell background
    init_pair(2,COLOR_YELLOW,COLOR_RED);
    init_pair(3,COLOR_RED,COLOR_BLACK);
    init_pair(4,COLOR_YELLOW,COLOR_BLUE);   // title window
    init_pair(5,COLOR_YELLOW,COLOR_BLACK);  // register/signal windows
    init_pair(6,COLOR_RED,COLOR_BLACK);
//    init_pair(7,COLOR_MAGENTA,COLOR_BLACK); // pipeline window
  }
  curs_set(0);
  noecho();
  cbreak();
  keypad(stdscr,TRUE);
  wbkgd(stdscr,COLOR_PAIR(1));
  wrefresh(stdscr);
//  int pipe_width=0;

  //instantiate the title window at top of screen
  title_win = create_newwin(3,COLS,0,0,4);
  mvwprintw(title_win,1,1,"SIMULATION INTERFACE V1");
  mvwprintw(title_win,1,COLS-22,"Modified by G7");
  wrefresh(title_win);

  //instantiate time window at right hand side of screen
  time_win = create_newwin(3,10,8,COLS-10,5);
  mvwprintw(time_win,0,3,"TIME");
  wrefresh(time_win);

WINDOW *title_win;
WINDOW *comment_win;
WINDOW *time_win;
WINDOW *sim_time_win;
WINDOW *instr_win;
WINDOW *clock_win;
WINDOW *pc_win;
WINDOW *id_win;
WINDOW *rat_win;
WINDOW *prf_r_win;
WINDOW *prf_win;
WINDOW *rrat_win;
WINDOW *rob_win;
WINDOW *rs_win;
WINDOW *ex_win;
WINDOW *cdb_win;
WINDOW *wb_win;
WINDOW *misc_win;

  //instantiate a sim time window which states the actual simlator time
  sim_time_win = create_newwin(3,10,11,COLS-10,5);
  mvwprintw(sim_time_win,0,1,"SIM TIME");
  wrefresh(sim_time_win);

  //instantiate a window to show which clock edge this is
  clock_win = create_newwin(6,15,8,COLS-25,5);
  mvwprintw(clock_win,0,5,"CLOCK");
  mvwprintw(clock_win,1,1,"cycle:");
  update_clock(0);
  wrefresh(clock_win);
  
 
  // instantiate a window for the ARF on the right side
  prf_r_win = create_newwin(49,25,14,COLS-25,5);
  mvwprintw(prf_r_win,0,13,"PRF");
  int i=0;
  char tmp_buf[48];
  for (; i < NUM_PRF; i++) {
    sprintf(tmp_buf, "%02d: ", i);
    mvwprintw(prf_r_win,i+1,1,tmp_buf);
  }
  wrefresh(prf_r_win);


  //instantiate window to visualize IF stage (including IF/ID)
  pc_win = create_newwin((num_pc_regs+2),30,8,0,5);
  mvwprintw(pc_win,0,10,"IF STAGE");
  wrefresh(pc_win);
  
    //instantiate window to visualize Id stage (including IF/ID)
  id_win = create_newwin((num_id_regs+2),30,8,30,5);
  mvwprintw(id_win,0,10,"ID STAGE");
  wrefresh(id_win);

  //instantiate window to visualize rat signals
  rat_win = create_newwin((num_rat_regs+2),30,8,60,5);
  mvwprintw(rat_win,0,12,"RAT");
  wrefresh(rat_win);


  //instantiate window to visualize rat signals
  rrat_win = create_newwin((num_rrat_regs+2),30,LINES-7-(num_wb_regs+2),0,5);
  mvwprintw(rrat_win,0,12,"RRAT");
  wrefresh(rrat_win);
  
  //instantiate a window to visualize ID stage
  rs_win = create_newwin((num_rs_regs+2),30,8,90,5);
  mvwprintw(rs_win,0,10,"RS");
  wrefresh(rs_win);

  //instantiate a window to visualize ID/EX signals
  rob_win = create_newwin((num_rob_regs+2),30,8,120,5);
  mvwprintw(rob_win,0,12,"ROB");
  wrefresh(rob_win);

  //instantiate a window to visualize EX stage
  ex_win = create_newwin((num_ex_regs+2),30,8,150,5);
  mvwprintw(ex_win,0,10,"EX");
  wrefresh(ex_win);

  //instantiate a window to visualize EX/MEM
  cdb_win = create_newwin((num_cdb_regs+2),30,8,180,5);
  mvwprintw(cdb_win,0,12,"CDB");
  wrefresh(cdb_win);

  //instantiate a window to visualize WB stage
  wb_win = create_newwin((num_wb_regs+2),30,LINES-7-(num_wb_regs+2),90,5);
  mvwprintw(wb_win,0,10,"WB");
  wrefresh(wb_win);

  //instantiate an instructional window to help out the user some
  instr_win = create_newwin(7,30,LINES-7,0,5);
  mvwprintw(instr_win,0,9,"INSTRUCTIONS");
  wattron(instr_win,COLOR_PAIR(5));
  mvwaddstr(instr_win,1,1,"'n'   -> Next clock edge");
  mvwaddstr(instr_win,2,1,"'b'   -> Previous clock edge");
  mvwaddstr(instr_win,3,1,"'c/g' -> Goto specified time");
  mvwaddstr(instr_win,4,1,"'r'   -> Run to end of sim");
  mvwaddstr(instr_win,5,1,"'q'   -> Quit Simulator");
  wrefresh(instr_win);
  
  // instantiate window to visualize misc regs/wires
  misc_win = create_newwin(7,COLS-25-30,LINES-7,30,5);
  mvwprintw(misc_win,0,(COLS-30-30)/2-6,"MISC SIGNALS");
  wrefresh(misc_win);

  refresh();
}

// This function updates all of the signals being displayed with the values
// from time history_num_in (this is the index into all of the data arrays).
// If the value changed from what was previously display, the signal has its
// display color inverted to make it pop out.
void parsedata(int history_num_in){
  static int old_history_num_in=0;
  static int old_head_position=0;
  static int old_tail_position=0;
  int i=0;
  int data_counter=0;
  char *opcode;
  int tmp=0;
  int tmp_val=0;
  char tmp_buf[48];
//  int pipe_width = COLS/6;

  // Handle updating resets
  if (resets[history_num_in]) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"RESET");
    wattroff(title_win,A_REVERSE);
  }
  else if (done_time != 0 && (history_num_in == done_time)) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"DONE ");
    wattroff(title_win,A_REVERSE);
  }
  else
    mvwprintw(title_win,1,(COLS/2)-3,"     ");
  wrefresh(title_win);
  
    // Handle updating the PRF window
  for (i=0; i < 48; i++) {
    if (strncmp(prf_r_contents[history_num_in]+i*16,
                prf_r_contents[old_history_num_in]+i*16,16))
      wattron(prf_r_win, A_REVERSE);
    else
      wattroff(prf_r_win, A_REVERSE);
    mvwaddnstr(prf_r_win,i+1,6,prf_r_contents[history_num_in]+i*16,16);
  }
  wrefresh(prf_r_win);


  // Handle updating the PC window
  for(i=0;i<num_pc_regs;i++){
    if (strcmp(pc_contents[history_num_in][i],
                pc_contents[old_history_num_in][i]))
      wattron(pc_win, A_REVERSE);
    else
      wattroff(pc_win, A_REVERSE);
    mvwaddstr(pc_win,i+1,strlen(pc_reg_names[i])+3,pc_contents[history_num_in][i]);
  }
  wrefresh(pc_win);

  // Handle updating the IF/ID window
  for(i=0;i<num_id_regs;i++){
    if (strcmp(id_contents[history_num_in][i],
                id_contents[old_history_num_in][i]))
      wattron(id_win, A_REVERSE);
    else
      wattroff(id_win, A_REVERSE);
    mvwaddstr(id_win,i+1,strlen(id_reg_names[i])+3,id_contents[history_num_in][i]);
  }
  wrefresh(id_win);

  // Handle updating the RAT window
  for(i=0;i<num_rat_regs;i++){
    if (strcmp(rat_contents[history_num_in][i],
                rat_contents[old_history_num_in][i]))
      wattron(rat_win, A_REVERSE);
    else
      wattroff(rat_win, A_REVERSE);
    mvwaddstr(rat_win,i+1,strlen(rat_reg_names[i])+3,rat_contents[history_num_in][i]);
  }
  wrefresh(rat_win);

  // Handle updating the RRAT window
  for(i=0;i<num_rrat_regs;i++){
    if (strcmp(rrat_contents[history_num_in][i],
                rrat_contents[old_history_num_in][i]))
      wattron(rrat_win, A_REVERSE);
    else
      wattroff(rat_win, A_REVERSE);
    mvwaddstr(rrat_win,i+1,strlen(rrat_reg_names[i])+3,rrat_contents[history_num_in][i]);
  }
  wrefresh(rrat_win);
  
    // Handle updating the rob window
  for(i=0;i<num_rob_regs;i++){
    if (strcmp(rob_contents[history_num_in][i],
                rob_contents[old_history_num_in][i]))
      wattron(rob_win, A_REVERSE);
    else
      wattroff(rob_win, A_REVERSE);
    mvwaddstr(rob_win,i+1,strlen(rob_reg_names[i])+3,rob_contents[history_num_in][i]);
  }
  wrefresh(rob_win);
  
    // Handle updating the rs window
  for(i=0;i<num_rs_regs;i++){
    if (strcmp(rs_contents[history_num_in][i],
                rs_contents[old_history_num_in][i]))
      wattron(rs_win, A_REVERSE);
    else
      wattroff(rs_win, A_REVERSE);
    mvwaddstr(rs_win,i+1,strlen(rs_reg_names[i])+3,rs_contents[history_num_in][i]);
  }
  wrefresh(rs_win);
  

  // Handle updating the prf window
  for(i=0;i<num_prf_regs;i++){
    if (strcmp(prf_contents[history_num_in][i],
                prf_contents[old_history_num_in][i]))
      wattron(prf_win, A_REVERSE);
    else
      wattroff(prf_win, A_REVERSE);
    mvwaddstr(prf_win,i+1,strlen(prf_reg_names[i])+3,prf_contents[history_num_in][i]);
  }
  wrefresh(prf_win);

  // Handle updating the EX window
  for(i=0;i<num_ex_regs;i++){
    if (strcmp(ex_contents[history_num_in][i],
                ex_contents[old_history_num_in][i]))
      wattron(ex_win, A_REVERSE);
    else
      wattroff(ex_win, A_REVERSE);
    mvwaddstr(ex_win,i+1,strlen(ex_reg_names[i])+3,ex_contents[history_num_in][i]);
  }
  wrefresh(ex_win);

  // Handle updating the cdb window
  for(i=0;i<num_cdb_regs;i++){
    if (strcmp(cdb_contents[history_num_in][i],
                cdb_contents[old_history_num_in][i]))
      wattron(cdb_win, A_REVERSE);
    else
      wattroff(cdb_win, A_REVERSE);
    mvwaddstr(cdb_win,i+1,strlen(cdb_reg_names[i])+3,cdb_contents[history_num_in][i]);
  }
  wrefresh(cdb_win);


  // Handle updating the WB window
  for(i=0;i<num_wb_regs;i++){
    if (strcmp(wb_contents[history_num_in][i],
                wb_contents[old_history_num_in][i]))
      wattron(wb_win, A_REVERSE);
    else
      wattroff(wb_win, A_REVERSE);
    mvwaddstr(wb_win,i+1,strlen(wb_reg_names[i])+3,wb_contents[history_num_in][i]);
  }
  wrefresh(wb_win);

  // Handle updating the misc. window
  int row=1,col=1;
  for (i=0;i<num_misc_regs;i++){
    if (strcmp(misc_contents[history_num_in][i],
                misc_contents[old_history_num_in][i]))
      wattron(misc_win, A_REVERSE);
    else
      wattroff(misc_win, A_REVERSE);
    

    mvwaddstr(misc_win,(i%5)+1,((i/5)*30)+strlen(misc_reg_names[i])+3,misc_contents[history_num_in][i]);
    if ((++row)>6) {
      row=1;
      col+=30;
    }
  }
  wrefresh(misc_win);

  //update the time window
  mvwaddstr(time_win,1,1,timebuffer[history_num_in]);
  wrefresh(time_win);

  //update to the correct clock edge for this history
  mvwaddstr(clock_win,1,7,cycles[history_num_in]);
  update_clock(clocks[history_num_in]);

  //save the old history index to check for changes later
  old_history_num_in = history_num_in;
}

// Parse a line of data output from the testbench
int processinput(){
  static int byte_num = 0;
  static int pc_reg_num = 0;
  static int id_reg_num = 0;
  static int rs_reg_num = 0;
  static int rrat_reg_num = 0;
  static int ex_reg_num = 0;
  static int cdb_reg_num = 0;
  static int rob_reg_num = 0;
  static int rat_reg_num = 0;
  static int wb_reg_num = 0;
  static int misc_reg_num = 0;
  static int prf_reg_num = 0;
  int tmp_len;
  char name_buf[48];
  char val_buf[48];

  //get rid of newline character
  readbuffer[strlen(readbuffer)-1] = 0;

  if(strncmp(readbuffer,"t",1) == 0){

    //We are getting the timestamp
    strcpy(timebuffer[history_num],readbuffer+1);
  }else if(strncmp(readbuffer,"c",1) == 0){

    //We have a clock edge/cycle count signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      clocks[history_num] = 0;
    else
      clocks[history_num] = 1;

    // grab clock count (for some reason, first clock count sent is
    // too many digits, so check for this)
    strncpy(cycles[history_num],readbuffer+2,7);
    if (strncmp(cycles[history_num],"       ",7) == 0)
      cycles[history_num][6] = '0';
    
  }else if(strncmp(readbuffer,"z",1) == 0){
    
    // we have a reset signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      resets[history_num] = 0;
    else
      resets[history_num] = 1;

  }else if(strncmp(readbuffer,"a",1) == 0){
    // We are getting PRF registers
    strcpy(prf_r_contents[history_num], readbuffer+1);

  }else if(strncmp(readbuffer,"p",1) == 0){			//1
    // We are getting an IF register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, pc_reg_num, pc_contents, pc_reg_names);
      mvwaddstr(pc_win,pc_reg_num+1,1,pc_reg_names[pc_reg_num]);
      waddstr(pc_win, ": ");
      wrefresh(pc_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(pc_contents[history_num][pc_reg_num],val_buf);
    }

    pc_reg_num++;
  }else if(strncmp(readbuffer,"g",1) == 0){			//2
    // We are getting an ID register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, id_reg_num, id_contents, id_reg_names);
      mvwaddstr(id_win,id_reg_num+1,1,id_reg_names[id_reg_num]);
      waddstr(id_win, ": ");
      wrefresh(id_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(id_contents[history_num][id_reg_num],val_buf);
    }

    id_reg_num++;
  }else if(strncmp(readbuffer,"r",1) == 0){			//3
    // We are getting an RAT register
    
    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, rat_reg_num, rat_contents, rat_reg_names);
      mvwaddstr(rat_win,rat_reg_num+1,1,rat_reg_names[rat_reg_num]);
      waddstr(rat_win, ": ");
      wrefresh(rat_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(rat_contents[history_num][rat_reg_num],val_buf);
    }

    rat_reg_num++;
  }else if(strncmp(readbuffer,"e",1) == 0){			//4
    // We are getting RRAT register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, rrat_reg_num, rrat_contents, rrat_reg_names);
      mvwaddstr(rrat_win,rrat_reg_num+1,1,rrat_reg_names[rrat_reg_num]);
      waddstr(rrat_win, ": ");
      wrefresh(rrat_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(rrat_contents[history_num][rrat_reg_num],val_buf);
    }

    rrat_reg_num++;
  }else if(strncmp(readbuffer,"f",1) == 0){			//5
    // We are getting an RRAT register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, prf_reg_num, prf_contents, prf_reg_names);
      mvwaddstr(prf_win,prf_reg_num+1,1,prf_reg_names[prf_reg_num]);
      waddstr(prf_win, ": ");
      wrefresh(prf_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(prf_contents[history_num][prf_reg_num],val_buf);
    }

    prf_reg_num++;
  }else if(strncmp(readbuffer,"x",1) == 0){			//6
    // We are getting an ex register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, ex_reg_num, ex_contents, ex_reg_names);
      mvwaddstr(ex_win,ex_reg_num+1,1,ex_reg_names[ex_reg_num]);
      waddstr(ex_win, ": ");
      wrefresh(ex_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(ex_contents[history_num][ex_reg_num],val_buf);
    }

    ex_reg_num++;
  }else if(strncmp(readbuffer,"i",1) == 0){			//7
    // We are getting an ROB register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, rob_reg_num, rob_contents, rob_reg_names);
      mvwaddstr(rob_win,rob_reg_num+1,1,rob_reg_names[rob_reg_num]);
      waddstr(rob_win, ": ");
      wrefresh(rob_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(rob_contents[history_num][rob_reg_num],val_buf);
    }

    rob_reg_num++;
  }else if(strncmp(readbuffer,"d",1) == 0){			//8
    // We are getting an cdb register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, cdb_reg_num, cdb_contents, cdb_reg_names);
      mvwaddstr(cdb_win,cdb_reg_num+1,1,cdb_reg_names[cdb_reg_num]);
      waddstr(cdb_win, ": ");
      wrefresh(cdb_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(cdb_contents[history_num][cdb_reg_num],val_buf);
    }

    cdb_reg_num++;
  }else if(strncmp(readbuffer,"s",1) == 0){			//9
    // We are getting a MEM register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, rs_reg_num, rs_contents, rs_reg_names);
      mvwaddstr(rs_win,rs_reg_num+1,1,rs_reg_names[rs_reg_num]);
      waddstr(rs_win, ": ");
      wrefresh(rs_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(rs_contents[history_num][rs_reg_num],val_buf);
    }

    rs_reg_num++;
  }else if(strncmp(readbuffer,"w",1) == 0){			//10
    // We are getting a WB register

    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, wb_reg_num, wb_contents, wb_reg_names);
      mvwaddstr(wb_win,wb_reg_num+1,1,wb_reg_names[wb_reg_num]);
      waddstr(wb_win, ": ");
      wrefresh(wb_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(wb_contents[history_num][wb_reg_num],val_buf);
    }

    wb_reg_num++;
  }else if(strncmp(readbuffer,"v",1) == 0){			//11

    //we are processing misc register/wire data
    // If this is the first time we've seen the register,
    // add name and data to arrays
    if (!setup_registers) {
      parse_register(readbuffer, misc_reg_num, misc_contents, misc_reg_names);
      mvwaddstr(misc_win,(misc_reg_num%5)+1,(misc_reg_num/5)*30+1,misc_reg_names[misc_reg_num]);
      waddstr(misc_win, ": ");
      wrefresh(misc_win);
    } else {
      sscanf(readbuffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
      strcpy(misc_contents[history_num][misc_reg_num],val_buf);
    }

    misc_reg_num++;
  }else if (strncmp(readbuffer,"break",4) == 0) {
    // If this is the first time through, indicate that we've setup all of
    // the register arrays.
    setup_registers = 1;

    //we've received our last data segment, now go process it
    byte_num = 0;
    pc_reg_num = 0;
    id_reg_num = 0;
    rs_reg_num = 0;
    rrat_reg_num = 0;
    ex_reg_num = 0;
    cdb_reg_num = 0;
    rat_reg_num = 0;
    cdb_reg_num = 0;
    rob_reg_num = 0;
    wb_reg_num = 0;
    misc_reg_num = 0;

    //update the simulator time, this won't change with 'b's
    mvwaddstr(sim_time_win,1,1,timebuffer[history_num]);
    wrefresh(sim_time_win);

    //tell the parent application we're ready to move on
    return(1); 
  }
  return(0);
}

//this initializes a ncurses window and sets up the arrays for exchanging reg information
void initcurses(int pc_regs, int id_regs, int rat_regs, int prf_regs, int rrat_regs,
                int rob_regs, int rs_regs, int ex_regs, int cdb_regs, int wb_regs,
                int misc_regs){
  int nbytes;
  int ready_val;

  done_state = 0;
  echo_data = 1;
  num_misc_regs = misc_regs;
  num_pc_regs = pc_regs;
  num_id_regs = id_regs;
  num_rat_regs = rat_regs;
  num_prf_regs = prf_regs;
  num_rrat_regs = rrat_regs;
  num_rob_regs = rob_regs;
  num_rs_regs = rs_regs;
  num_ex_regs = ex_regs;
  num_cdb_regs = cdb_regs;
  num_wb_regs = wb_regs;
  pid_t childpid;
  pipe(readpipe);
  pipe(writepipe);
  stdout_save = dup(1);
  childpid = fork();
  if(childpid == 0){
    close(PARENT_WRITE);
    close(PARENT_READ);
    fp = fdopen(CHILD_READ, "r");
    fp2 = fopen("program.out","w");

    //allocate room on the heap for the reg data
    inst_contents     = (char**) malloc(NUM_HISTORY*sizeof(char*));
    prf_r_contents      = (char**) malloc(NUM_HISTORY*sizeof(char*));
    int i=0;
    pc_contents       = (char***) malloc(NUM_HISTORY*sizeof(char**));
    id_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    ex_contents       = (char***) malloc(NUM_HISTORY*sizeof(char**));
    rs_contents    = (char***) malloc(NUM_HISTORY*sizeof(char**));
    cdb_contents       = (char***) malloc(NUM_HISTORY*sizeof(char**));
    rob_contents   = (char***) malloc(NUM_HISTORY*sizeof(char**));
    rat_contents      = (char***) malloc(NUM_HISTORY*sizeof(char**));
    rrat_contents   = (char***) malloc(NUM_HISTORY*sizeof(char**));
    prf_contents   = (char***) malloc(NUM_HISTORY*sizeof(char**));
    wb_contents       = (char***) malloc(NUM_HISTORY*sizeof(char**));
    misc_contents     = (char***) malloc(NUM_HISTORY*sizeof(char**));
    timebuffer        = (char**) malloc(NUM_HISTORY*sizeof(char*));
    cycles            = (char**) malloc(NUM_HISTORY*sizeof(char*));
    clocks            = (char*) malloc(NUM_HISTORY*sizeof(char));
    resets            = (char*) malloc(NUM_HISTORY*sizeof(char));

    // allocate room for the register names (what is displayed)
    pc_reg_names      = (char**) malloc(num_pc_regs*sizeof(char*));
    id_reg_names   = (char**) malloc(num_id_regs*sizeof(char*));
    rat_reg_names      = (char**) malloc(num_rat_regs*sizeof(char*));
    prf_reg_names   = (char**) malloc(num_prf_regs*sizeof(char*));
    rrat_reg_names      = (char**) malloc(num_rrat_regs*sizeof(char*));
    rob_reg_names  = (char**) malloc(num_rob_regs*sizeof(char*));
    rs_reg_names     = (char**) malloc(num_rs_regs*sizeof(char*));
    ex_reg_names  = (char**) malloc(num_ex_regs*sizeof(char*));
    cdb_reg_names      = (char**) malloc(num_cdb_regs*sizeof(char*));
    wb_reg_names    = (char**) malloc(num_wb_regs*sizeof(char*));
    misc_reg_names    = (char**) malloc(num_misc_regs*sizeof(char*));

    int j=0;
    for(;i<NUM_HISTORY;i++){
      timebuffer[i]       = (char*) malloc(8);
      cycles[i]           = (char*) malloc(7);
      inst_contents[i]    = (char*) malloc(NUM_STAGES*10);
      prf_r_contents[i]     = (char*) malloc(NUM_PRF*20);
      pc_contents[i]      = (char**) malloc(num_pc_regs*sizeof(char*));
      id_contents[i]   = (char**) malloc(num_id_regs*sizeof(char*));
      rat_contents[i]      = (char**) malloc(num_rat_regs*sizeof(char*));
      prf_contents[i]   = (char**) malloc(num_prf_regs*sizeof(char*));
      rrat_contents[i]      = (char**) malloc(num_rrat_regs*sizeof(char*));
      rob_contents[i]  = (char**) malloc(num_rob_regs*sizeof(char*));
      rs_contents[i]     = (char**) malloc(num_rs_regs*sizeof(char*));
      ex_contents[i]  = (char**) malloc(num_ex_regs*sizeof(char*));
      cdb_contents[i]      = (char**) malloc(num_cdb_regs*sizeof(char*));
      wb_contents[i]      = (char**) malloc(num_wb_regs*sizeof(char*));
      misc_contents[i]    = (char**) malloc(num_misc_regs*sizeof(char*));
    }
    setup_gui(fp);

    // Main loop for retrieving data and taking commands from user
    char quit_flag = 0;
    char resp=0;
    char running=0;
    int mem_addr=0;
    char goto_flag = 0;
    char cycle_flag = 0;
    char done_received = 0;
    memset(readbuffer,'\0',sizeof(readbuffer));
    while(!quit_flag){
      if (!done_received) {
        fgets(readbuffer, sizeof(readbuffer), fp);
        ready_val = processinput();
      }
      if(strcmp(readbuffer,"DONE") == 0) {
        done_received = 1;
        done_time = history_num - 1;
      }
      if(ready_val == 1 || done_received == 1){
        if(echo_data == 0 && done_received == 1) {
          running = 0;
          timeout(-1);
          echo_data = 1;
          history_num--;
          history_num%=NUM_HISTORY;
        }
        if(echo_data != 0){
          parsedata(history_num);
        }
        history_num++;
        // keep track of whether time wrapped around yet
        if (history_num == NUM_HISTORY)
          time_wrapped = 1;
        history_num%=NUM_HISTORY;

        //we're done reading the reg values for this iteration
        if (done_received != 1) {
          write(CHILD_WRITE, "n", 1);
          write(CHILD_WRITE, &mem_addr, 2);
        }
        char continue_flag = 0;
        int hist_num_temp = (history_num-1)%NUM_HISTORY;
        if (history_num==0) hist_num_temp = NUM_HISTORY-1;
        char echo_data_tmp,continue_flag_tmp;

        while(continue_flag == 0){
          resp=getch();
          if(running == 1){
            continue_flag = 1;
          }
          if(running == 0 || resp == 'p'){ 
            if(resp == 'n' && hist_num_temp == (history_num-1)%NUM_HISTORY){
              if (!done_received)
                continue_flag = 1;
            }else if(resp == 'n'){
              //forward in time, but not up to present yet
              hist_num_temp++;
              hist_num_temp%=NUM_HISTORY;
              parsedata(hist_num_temp);
            }else if(resp == 'r'){
              echo_data = 0;
              running = 1;
              timeout(0);
              continue_flag = 1;
            }else if(resp == 'p'){
              echo_data = 1;
              timeout(-1);
              running = 0;
              parsedata(hist_num_temp);
            }else if(resp == 'q'){
              //quit
              continue_flag = 1;
              quit_flag = 1;
            }else if(resp == 'b'){
              //We're goin BACK IN TIME, woohoo!
              // Make sure not to wrap around to NUM_HISTORY-1 if we don't have valid
              // data there (time_wrapped set to 1 when we wrap around to history 0)
              if (hist_num_temp > 0) {
                hist_num_temp--;
                parsedata(hist_num_temp);
              } else if (time_wrapped == 1) {
                hist_num_temp = NUM_HISTORY-1;
                parsedata(hist_num_temp);
              }
            }else if(resp == 'g' || resp == 'c'){
              // See if user wants to jump to clock cycle instead of sim time
              cycle_flag = (resp == 'c');

              // go to specified simulation time (either in history or
              // forward in simulation time).
              stop_time = get_time();
              
              // see if we already have that time in history
              int tmp_time;
              int cur_time;
              int delta;
              if (cycle_flag)
                sscanf(cycles[hist_num_temp], "%u", &cur_time);
              else
                sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
              delta = (stop_time > cur_time) ? 1 : -1;
              if ((hist_num_temp+delta)%NUM_HISTORY != history_num) {
                tmp_time=hist_num_temp;
                i= (hist_num_temp+delta >= 0) ? (hist_num_temp+delta)%NUM_HISTORY : NUM_HISTORY-1;
                while (i!=history_num) {
                  if (cycle_flag)
                    sscanf(cycles[i], "%u", &cur_time);
                  else
                    sscanf(timebuffer[i], "%u", &cur_time);
                  if ((delta == 1 && cur_time >= stop_time) ||
                      (delta == -1 && cur_time <= stop_time)) {
                    hist_num_temp = i;
                    parsedata(hist_num_temp);
                    stop_time = 0;
                    break;
                  }

                  if ((i+delta) >=0)
                    i = (i+delta)%NUM_HISTORY;
                  else {
                    if (time_wrapped == 1)
                      i = NUM_HISTORY - 1;
                    else {
                      parsedata(hist_num_temp);
                      stop_time = 0;
                      break;
                    }
                  }
                }
              }

              // If we looked backwards in history and didn't find stop_time
              // then give up
              if (i==history_num && (delta == -1 || done_received == 1))
                stop_time = 0;

              // Set flags so that we run forward in the simulation until
              // it either ends, or we hit the desired time
              if (stop_time > 0) {
                // grab current values
                echo_data = 0;
                running = 1;
                timeout(0);
                continue_flag = 1;
                goto_flag = 1;
              }
            }
          }
        }
        // if we're instructed to goto specific time, see if we're there
        int cur_time=0;
        if (goto_flag==1) {
          if (cycle_flag)
            sscanf(cycles[hist_num_temp], "%u", &cur_time);
          else
            sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
          if ((cur_time >= stop_time) ||
              (strcmp(readbuffer,"DONE")==0) ) {
            goto_flag = 0;
            echo_data = 1;
            running = 0;
            timeout(-1);
            continue_flag = 0;
            //parsedata(hist_num_temp);
          }
        }
      }
    }
    refresh();
    delwin(title_win);
    endwin();
    fflush(stdout);
    if(resp == 'q'){
      fclose(fp2);
      write(CHILD_WRITE, "Z", 1);
      exit(0);
    }
    readbuffer[0] = 0;
    while(strncmp(readbuffer,"DONE",4) != 0){
      if(fgets(readbuffer, sizeof(readbuffer), fp) != NULL)
        fputs(readbuffer, fp2);
    }
    fclose(fp2);
    fflush(stdout);
    write(CHILD_WRITE, "Z", 1);
    printf("Child Done Execution\n");
    exit(0);
  } else {
    close(CHILD_READ);
    close(CHILD_WRITE);
    dup2(PARENT_WRITE, 1);
    close(PARENT_WRITE);
    
  }
}


// Function to make testbench block until debugger is ready to proceed
int waitforresponse(){
  static int mem_start = 0;
  char c=0;
  while(c!='n' && c!='Z') read(PARENT_READ,&c,1);
  if(c=='Z') exit(0);
  mem_start = read(PARENT_READ,&c,1);
  mem_start = mem_start << 8 + read(PARENT_READ,&c,1);
  return(mem_start);
}

void flushpipe(){
  char c=0;
  read(PARENT_READ, &c, 1);
}

// Function to return string representation of opcode given inst encoding
char *get_opcode_str(int inst, int valid_inst)
{
  int opcode, check;
  char *str;
  
  if (valid_inst == ((int)'x' - (int)'0'))
    str = "-";
  else if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    opcode = (inst >> 26) & 0x0000003f;
    check = (inst>>5) & 0x0000007f;
    switch(opcode)
    {
      case 0x00: str = (inst == 0x555) ? "halt" : "call_pal"; break;
      case 0x08: str = "lda"; break;
      case 0x09: str = "ldah"; break;
      case 0x0a: str = "ldbu"; break;
      case 0x0b: str = "ldqu"; break;
      case 0x0c: str = "ldwu"; break;
      case 0x0d: str = "stw"; break;
      case 0x0e: str = "stb"; break;
      case 0x0f: str = "stqu"; break;
      case 0x10: // INTA_GRP
         switch(check)
         {
           case 0x00: str = "addl"; break;
           case 0x02: str = "s4addl"; break;
           case 0x09: str = "subl"; break;
           case 0x0b: str = "s4subl"; break;
           case 0x0f: str = "cmpbge"; break;
           case 0x12: str = "s8addl"; break;
           case 0x1b: str = "s8subl"; break;
           case 0x1d: str = "cmpult"; break;
           case 0x20: str = "addq"; break;
           case 0x22: str = "s4addq"; break;
           case 0x29: str = "subq"; break;
           case 0x2b: str = "s4subq"; break;
           case 0x2d: str = "cmpeq"; break;
           case 0x32: str = "s8addq"; break;
           case 0x3b: str = "s8subq"; break;
           case 0x3d: str = "cmpule"; break;
           case 0x40: str = "addlv"; break;
           case 0x49: str = "sublv"; break;
           case 0x4d: str = "cmplt"; break;
           case 0x60: str = "addqv"; break;
           case 0x69: str = "subqv"; break;
           case 0x6d: str = "cmple"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x11: // INTL_GRP
         switch(check)
         {
           case 0x00: str = "and"; break;
           case 0x08: str = "bic"; break;
           case 0x14: str = "cmovlbs"; break;
           case 0x16: str = "cmovlbc"; break;
           case 0x20: str = "bis"; break;
           case 0x24: str = "cmoveq"; break;
           case 0x26: str = "cmovne"; break;
           case 0x28: str = "ornot"; break;
           case 0x40: str = "xor"; break;
           case 0x44: str = "cmovlt"; break;
           case 0x46: str = "cmovge"; break;
           case 0x48: str = "eqv"; break;
           case 0x61: str = "amask"; break;
           case 0x64: str = "cmovle"; break;
           case 0x66: str = "cmovgt"; break;
           case 0x6c: str = "implver"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x12: // INTS_GRP
         switch(check)
         {
           case 0x02: str = "mskbl"; break;
           case 0x06: str = "extbl"; break;
           case 0x0b: str = "insbl"; break;
           case 0x12: str = "mskwl"; break;
           case 0x16: str = "extwl"; break;
           case 0x1b: str = "inswl"; break;
           case 0x22: str = "mskll"; break;
           case 0x26: str = "extll"; break;
           case 0x2b: str = "insll"; break;
           case 0x30: str = "zap"; break;
           case 0x31: str = "zapnot"; break;
           case 0x32: str = "mskql"; break;
           case 0x34: str = "srl"; break;
           case 0x36: str = "extql"; break;
           case 0x39: str = "sll"; break;
           case 0x3b: str = "insql"; break;
           case 0x3c: str = "sra"; break;
           case 0x52: str = "mskwh"; break;
           case 0x57: str = "inswh"; break;
           case 0x5a: str = "extwh"; break;
           case 0x62: str = "msklh"; break;
           case 0x67: str = "inslh"; break;
           case 0x6a: str = "extlh"; break;
           case 0x72: str = "mskqh"; break;
           case 0x77: str = "insqh"; break;
           case 0x7a: str = "extqh"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x13: // INTM_GRP
         switch(check)
         {
           case 0x00: str = "mull"; break;
           case 0x20: str = "mulq"; break;
           case 0x30: str = "umulh"; break;
           case 0x40: str = "mullv"; break;
           case 0x60: str = "mulqv"; break;
           default: str = "invalid"; break;
         }
         break;
      case 0x14: str = "itfp"; break; // unimplemented
      case 0x15: str = "fltv"; break; // unimplemented
      case 0x16: str = "flti"; break; // unimplemented
      case 0x17: str = "fltl"; break; // unimplemented
      case 0x1a: str = "jsr"; break;
      case 0x1c: str = "ftpi"; break;
      case 0x20: str = "ldf"; break;
      case 0x21: str = "ldg"; break;
      case 0x22: str = "lds"; break;
      case 0x23: str = "ldt"; break;
      case 0x24: str = "stf"; break;
      case 0x25: str = "stg"; break;
      case 0x26: str = "sts"; break;
      case 0x27: str = "stt"; break;
      case 0x28: str = "ldl"; break;
      case 0x29: str = "ldq"; break;
      case 0x2a: str = "ldll"; break;
      case 0x2b: str = "ldql"; break;
      case 0x2c: str = "stl"; break;
      case 0x2d: str = "stq"; break;
      case 0x2e: str = "stlc"; break;
      case 0x2f: str = "stqc"; break;
      case 0x30: str = "br"; break;
      case 0x31: str = "fbeq"; break;
      case 0x32: str = "fblt"; break;
      case 0x33: str = "fble"; break;
      case 0x34: str = "bsr"; break;
      case 0x35: str = "fbne"; break;
      case 0x36: str = "fbge"; break;
      case 0x37: str = "fbgt"; break;
      case 0x38: str = "blbc"; break;
      case 0x39: str = "beq"; break;
      case 0x3a: str = "blt"; break;
      case 0x3b: str = "ble"; break;
      case 0x3c: str = "blbs"; break;
      case 0x3d: str = "bne"; break;
      case 0x3e: str = "bge"; break;
      case 0x3f: str = "bgt"; break;
      default: str = "invalid"; break;
    }
  }

  return str;
}

// Function to parse register $display() from testbench and add to
// names/contents arrays
void parse_register(char *readbuf, int reg_num, char*** contents, char** reg_names) {
  char name_buf[48];
  char val_buf[48];
  int tmp_len;

  sscanf(readbuf,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
  int i=0;
  for (;i<NUM_HISTORY;i++){
    contents[i][reg_num] = (char*) malloc((tmp_len+1)*sizeof(char));
  }
  strcpy(contents[history_num][reg_num],val_buf);
  reg_names[reg_num] = (char*) malloc((strlen(name_buf)+1)*sizeof(char));
  strncpy(reg_names[reg_num], readbuf+1, strlen(name_buf));
  reg_names[reg_num][strlen(name_buf)] = '\0';
}

// Ask user for simulation time to stop at
// Since the enter key isn't detected, user must press 'g' key
//  when finished entering a number.
int get_time() {
  int col = COLS/2-6;
  wattron(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"goto time: ");
  wrefresh(title_win);
  int resp=0;
  int ptr = 0;
  char buf[48];
  int i;
  
  resp=wgetch(title_win);
  while(resp != 'g' && resp != KEY_ENTER && resp != ERR && ptr < 6) {
    if (isdigit((char)resp)) {
      waddch(title_win,(char)resp);
      wrefresh(title_win);
      buf[ptr++] = (char)resp;
    }
    resp=wgetch(title_win);
  }

  // Clean up title window
  wattroff(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"           ");
  for(i=0;i<ptr;i++)
    waddch(title_win,' ');

  wrefresh(title_win);

  buf[ptr] = '\0';
  return atoi(buf);
}