/* Credits:  7/19/93 - Thanks to Michael G. Reed for submitting the
 *           code to trap core dump and make this section more dynamic.
 *
 * This code is derived from Argonne National Labs' anlpasswd suite.
 * 
 * Jesse Vincent hacked at it and generalized things a bit for RT.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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

  if (!(eargv = (char **) malloc ((argc + 4) * sizeof (char *))))
    {
      fprintf (stderr, "%s: Failed to obtain memory.\n", program_name);
      exit (1);                                  /* Trap core dump! */
    }
  eargv[0]= PERL;
  eargv[1] = "-T";
  eargv[2] = RT_PERL_MUX;
  eargv[3] = program_name;


  for (i = 1; i < argc; i++)
    eargv[i+3] = argv[i];

  eargv[i+3] = NULL;

  execve(PERL, eargv, envp);
  fprintf (stderr, "%s: Failed to launch RT program.\n", program_name);
  perror (program_name);
}


