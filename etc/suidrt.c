/*  $Header$
 * Credits:  7/19/93 - Thanks to Michael G. Reed for submitting the
 *           code to trap core dump and make this section more dynamic.
 *
 * This code is derived from Argonne National Labs' anlpasswd suite.
 * 
 * Jesse Vincent hacked at it and generalized things a bit for RT.
 *
 * 30-sep-2000 -- Extensively hacked by Jan Kujawa to make suid switch
 *                safer, and allow for a list of ENV vars which are considered
 *                safe to pass to the child process.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

/*  This array contains the env vars we'll allow.
    Case-sensitive, of course.  */
const char* SAFE_ENV_VARS [] = {
  "MOD_PERL",
  "SERVER_ADMIN",
  "HTTP_COOKIE", 
  "COOKIE",
  "SERVER_SOFTWARE",
  "GATEWAY_INTERFACE",
  "REQUEST_METHOD",
  "CONTENT_LENGTH",
  "CONTENT_TYPE",
  "QUERY_STRING",
  "REDIRECT_QUERY_STRING",
  "SERVER_PROTOCOL",
   "REQUEST_URI",
   "PATH_INFO",
   "REQUEST_METHOD", 
   "PATH_TRANSLATED",
   "REMOTE_HOST",  
   "REMOTE_ADDR", 
   "SCRIPT_NAME",
   "SERVER_SOFTWARE",
   "SERVER_NAME",
   "SERVER_PROTOCOL", 
   "HTTPS", 
   "REMOTE_IDENT",
   "AUTH_TYPE",
   "REMOTE_USER",
   "PATH_INFO"
  "TZ",
  "HOST",
  "USERNAME",
  "TERM",
  "MAIL",
  NULL
};

/* perl params */


/* malloc or DIE! */
void* xmalloc(size_t size)
{
  void* retval=NULL;
  if( (retval=malloc(size))==NULL)
    {
      fprintf (stderr, "malloc() failed.\n");
      exit (1);                                  
    }
  return(retval);
}

/* 
Scan the environment for vars from SafeVars, and copy them to envp if they exist
*/
char** getSafeEnvironment(const char** SafeVars)
{
  char** envp;
  int i=0, numvars=0, pos=0;
  const char* candidate;
  char* val;
  int envStringLen;
  char* envString;

  /* first ve count ze gut ztrings */
  while( (candidate=SafeVars[i++])!=NULL)
    if( getenv(candidate) != NULL)
      numvars++;
  
  envp = (char **) xmalloc ( (numvars+1)*sizeof(char*));
  
  /* und zen ve copy zem */
  for(i=0;i<numvars;i++)
    if( (candidate=SafeVars[i])!=NULL)
      if( (val=getenv(candidate)) != NULL)
	{
	  envStringLen=strlen(val)+strlen(candidate)+2; 
	  envString=(char*)xmalloc(envStringLen);
	  strncpy(envString,candidate,strlen(candidate));
	  envString[strlen(candidate)]='=';
	  strncpy(envString+strlen(candidate)+1,val,strlen(val));
	  envp[pos++]=envString;
	}

  envp[numvars]=NULL;

  return(envp);
}

int main (int argc, char** argv)
{
  int    i;
  char  *program_name;
  char **eargv;
  char **envp;
  uid_t old_euid;

  /* temporarily drop privs */
  old_euid=geteuid();
  seteuid(getuid());

  if ( (program_name=strrchr(argv[0], '/'))!=NULL)   /* Get root program name */
    program_name++;
  else
    program_name = argv[0];

  eargv = (char **) malloc ((argc + 4) * sizeof (char *));

  eargv[0]= PERL;
  eargv[1] = "-T";
  eargv[2] = RT_PERL_MUX;
  eargv[3] = program_name;


  for (i = 1; i < argc; i++)
    eargv[i+3] = argv[i];

  eargv[i+3] = NULL;

  envp=getSafeEnvironment(SAFE_ENV_VARS);

  seteuid(old_euid);
  execve(PERL, eargv, envp);
  fprintf (stderr, "%s: Failed to launch RT program.\n%s\n", program_name,strerror(errno));
  return(1);
}
