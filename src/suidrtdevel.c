/* Credits:  7/19/93 - Thanks to Michael G. Reed for submitting the
 *           code to trap core dump and make this section more dynamic.
 *
 */
#include <stdio.h>
#include <string.h>

#define RTQ_ACTUAL "/usr/local/rt/lib/rtq.pl"
#define RT_ACTUAL "/usr/local/rt/lib/rt.pl"
#define WEBRT_ACTUAL "/usr/local/rt/lib/webrt.pl"
#define MAILGATE_ACTUAL "/usr/local/rt/lib/mailgate.pl"

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
  eargv[0]= "/usr/bin/perl";
  eargv[1] = "-w";

  if (!strcmp (program_name, "drt"))
    eargv[2] = RT_ACTUAL;
  else if (!strcmp (program_name, "drtq"))
    eargv[2] = RTQ_ACTUAL;
   else if (!strcmp (program_name, "dwebrt.cgi"))
    eargv[2] = WEBRT_ACTUAL;
  else if (!strcmp (program_name, "dmailgate"))
    eargv[2] = MAILGATE_ACTUAL;
  else
    {
      fprintf (stderr, "%s: Illegal launch program.\n", program_name);
      exit(1);
    }

  for (i = 1; i < argc; i++)
    eargv[i+2] = argv[i];
  execve("/usr/bin/perl", eargv, envp);
  fprintf (stderr, "%s: Failed to launch RT program.\n", program_name);
  perror (program_name);
}


