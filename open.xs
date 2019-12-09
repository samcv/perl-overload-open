#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

int is_global() {
    return SvTRUE(get_sv("overload::open::GLOBAL", 1));
}
#define overload_open_die_with_xs_sub 1
OP* (*real_pp_open)(pTHX);
OP* (*real_pp_sysopen)(pTHX);
PP(pp_overload_open) {
    dSP; dTARG;
    SV* hook;
    SV* sv;
    HV* saved_hh = NULL;
    I32 count, c, ax;
    /* hook is what we are calling instead of `open` */
    hook = get_sv("overload::open::GLOBAL", 0);
    int my_debug = 0;
    /* If the hook evaluates as false, we should just call the original
     * function ( AKA overload::open->override() has not been called yet ) */
    if ( !SvTRUE( hook ) ) {
        return real_pp_open(aTHX);
    }
    /* Check to make sure we have a coderef */
    if ( !SvROK( hook ) || SvTYPE( SvRV(hook) ) != SVt_PVCV ) {
        warn("override::open expected a code reference, but got something else");
        return real_pp_open(aTHX);
    }
    /* Get the CV* that the reference refers to */
    CV* code_hook = (CV*) SvRV(hook);
    if ( CvISXSUB( code_hook ) ) {
        if ( overload_open_die_with_xs_sub )
            die("overload::open Cowardly refusing to hook an XS sub");
        return real_pp_open(aTHX);
    }
    if (my_debug) sv_dump(TOPs);
    sv = TOPs;
    I32 depth = CvDEPTH(code_hook);
    /* CvDEPTH > 0 that means our hook is calling OP_OPEN. This is ok
     * just ensure we direct things to the original function */
    if ( 0 < CvDEPTH( code_hook ) ) {
        return real_pp_open(aTHX);
    }
    ENTER;
    SAVETMPS;
    /* Marking has to do with getting the number of arguments ? maybe. pushmark is start of the arguments */
    PUSHMARK(SP);
    XPUSHs(sv);
    PUTBACK;
    /* SP = Stack Pointer.
     * count is the number of arguments. call calls the function */
    count = call_sv( hook, G_VOID | G_DISCARD );
    if (count) {
        warn("Blah");
    }
    /* SPAGAIN makes me think of Spaghetti */
    SPAGAIN;
    /* FREETMPS and LEAV *probably* clean up the scope from the call_sv() */
    FREETMPS;
    LEAVE;
    if (my_debug) sv_dump(TOPs);
    return real_pp_open(aTHX);
}

MODULE = overload::open	PACKAGE = overload::open PREFIX = overload_open_

PROTOTYPES: ENABLE

void
_test_xs_function(...)
    CODE:
        printf("running test xs function\n");

void
_install_open(what_you_want)
    char *what_you_want
    CODE:
        real_pp_open = PL_ppaddr[OP_OPEN];
        PL_ppaddr[OP_OPEN] = Perl_pp_overload_open;
