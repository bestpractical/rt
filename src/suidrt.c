/* Credits:  7/19/93 - Thanks to Michael G. Reed for submitting the
 *           code to trap core dump and make this section more dynamic.
 *
 * This code is derived from Argonne National Labs' anlpasswd suite.
 * 
 * Jesse Vincent hacked at it and generalized things a bit for RT.
 *
 */
#include <stdio.h>
#include <string.h>

int main (argc, argv, envp)
int argc;
char *argv[],*envp[];

{
  int    i;
  char  *program_name;
  char **eargv;
  
  if (program_name = strrchr (argv[0], '/'))   /* Get root program name */
    program_name++;
  else
    program_name = argv[0];

  if (!(eargv = (char **) malloc ((argc + 3) * sizeof (char *))))
    {
      fprintf (stderr, "%s: Failed to obtain memory.\n", program_name);
      exit (1);                                  /* Trap core dump! */
    }
  eargv[0]= PERL;
  eargv[1] = "-U";
  eargv[2] = RTMUX;

  if (!strcmp (program_name, "rt")) {
    eargv[3] = "rt";	 
  }
  else if (!strcmp (program_name, "rtq")) {

    eargv[3]= "rtq";
  }
  else if (!strcmp (program_name, "nph-webrt.cgi")) {

    eargv[3] = "webrt";
  }
   else if (!strcmp (program_name, "nph-admin-webrt.cgi")) {

    eargv[3] = "adminwebrt"; 
   }
    else if (!strcmp (program_name, "rtadmin")) {

    eargv[3] = "rtadmin";
    }
  else if (!strcmp (program_name, "rt-mailgate")) {

    eargv[3] = "rtmailgate";
  }
    else
    {
      fprintf (stderr, "%s: Illegal launch program.\n", program_name);
      exit(1);
    }

  for (i = 1; i < argc; i++)
    eargv[i+3] = argv[i];
  execve(PERL, eargv, envp);
  fprintf (stderr, "%s: Failed to launch RT program.\n", program_name);
  perror (program_name);
}


