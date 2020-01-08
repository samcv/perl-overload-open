#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#define SAVE_AND_REPLACE_PP_IF_UNSET(real_function, op_to_replace, overload_function, OP_replace_mutex) do {\
    MUTEX_LOCK(&OP_replace_mutex);\
    if (PL_ppaddr[op_to_replace] != overload_function) {\
        /* Is this a race in threaded perl? */\
        real_function = PL_ppaddr[op_to_replace];\
        PL_ppaddr[op_to_replace] = overload_function;\
    }\
    else {\
        /* Would be nice if we could warn here. */\
    }\
    MUTEX_UNLOCK(&OP_replace_mutex);\
} while (0)

#define overload_open_die_with_xs_sub 1
#define overload_open_max_function_pointers 2
OP* (*stuff_array[overload_open_max_function_pointers])(pTHX);
/* Declare function pointers for OP's */
OP* (*real_pp_open)(pTHX) = NULL;
OP* (*real_pp_sysopen)(pTHX) = NULL;

#define overload_open_max_args 99
#ifdef USE_ITHREADS
static perl_mutex OP_OPEN_replace_mutex;
static perl_mutex OP_SYSOPEN_replace_mutex;
#endif

OP * (*real_pp_open)(pTHX);
OP * (*real_pp_sysopen)(pTHX);

OP * overload_allopen(char *opname, char *global, OP* (*real_pp_func)(pTHX)) {
    dSP; dTARG;
    SV *hook;
    SV *save_tops;
    SV *sv, *sv_array[overload_open_max_args];
    I32 refcnts[overload_open_max_args];
    I32 count, c, ax, my_topmark_after, i, sv_array_pos = 0;
    char buf[99];
    save_tops = TOPs;
    dMARK;
    dITEMS; /* Sets up the `items` variable */

    /* hook is what we are calling instead of `open` */
    hook = get_sv(global, 0);
    int my_debug = 0;
    /* If the hook evaluates as false, we should just call the original
     * function ( AKA overload::open->prehook_open() has not been called yet ) */
    if ( !hook || !SvTRUE( hook ) ) {
        return real_pp_func(aTHX);
    }
    /* Check to make sure we have a coderef */
    if ( !SvROK( hook ) || SvTYPE( SvRV(hook) ) != SVt_PVCV ) {
        warn("override::open expected a code reference, but got something else");
        return real_pp_func(aTHX);
    }
    /* Get the CV* that the reference refers to */
    CV* code_hook = (CV*) SvRV(hook);
    if ( CvISXSUB( code_hook ) ) {
        if ( overload_open_die_with_xs_sub )
            die("overload::open error. Cowardly refusing to hook an XS sub into %s", opname);
        return real_pp_func(aTHX);
    }

    /* CvDEPTH > 0 that means our hook is calling OP_OPEN. This is ok
     * just ensure we direct things to the original function */
    if ( 0 < CvDEPTH( code_hook ) ) {
        return real_pp_func(aTHX);
    }
    //dMARK;  /* Sets up the `mark` variable */
    //dITEMS; /* Sets up the `items` variable */
    /* Save the stack pointer location */
    SV** mysp = sp;
    /* Save the number of items (number of arguments) */
    I32 myitems = items + 1;
    for ( c = 0; c < myitems; c++ ) {
        sv_array[c] = ST(c);
        refcnts[c] = SvREFCNT(sv_array[c]);
        if (my_debug ) {
            sprintf(buf, "79 ST(%i) to sv_array[%i]\n", c, c);
            PerlIO_puts(PerlIO_stderr(), buf);
            sv_dump(sv_array[c]);
        }


        //SvREFCNT_inc(sv_array[c]);
    }
    for ( c = 0; c < myitems; c++) {
        SvREFCNT_inc(ST(c));
    }
    SvREFCNT_inc(TOPs);
    if (my_debug){
        PerlIO_puts(PerlIO_stderr(), "post sv_array TOPs\n");
        sv_dump(TOPs);
    }
    ENTER;
        /* Save the temporaries stack */
        SAVETMPS;
            /* Marking has to do with getting the number of arguments.
             * maybe. pushmark is start of the arguments
             *
             * The value stack stores individual perl scalar values as temporaries between
             * expressions. Some perl expressions operate on entire lists; for that purpose
             * we need to know where on the stack each list begins. This is the purpose of the
             * mark stack. */
            PUSHMARK(SP); /* SP = Stack Pointer. */
                /* sp != mysp */
                EXTEND(SP, myitems-1);
                for ( c = 1; c < myitems; c++ ) {
                    //ST(c) = sv_array[myitems-1-c];
                    /* There is probably a macro for the line below, but
                     * I couldn't find it :( */
                    //SV* mysv = sv_array[c] = *(mysp - c);
                    SV *mysv = sv_array[c];
                    //SvREFCNT_inc(sv_array[c]);
                    //mPUSHs(mysv);
                    PUSHs(mysv);
                    /* XPUSHs also extends by one (not needed?) */
                    /*XPUSHs(sv_2mortal(sv_array[c])); */
                }
            PUTBACK; /* Closing bracket for XSUB arguments */
            /* count is the number of arguments returned from the call. call_sv()
             * call calls the function `hook` */
            /* call_sv's return value is put on the SP stack */
            count = call_sv( hook, G_VOID | G_DISCARD );
            /* G_VOID and G_DISCARD should cause us to not ask for any return
             * arguments from the call. */
            if (count) {
                /* This should really never happen. Put a warn in there because */
                warn("call_sv was not supposed to get any arguments");
            }
            /* The purpose of the macro "SPAGAIN" is to refresh the local copy of
             * the stack pointer. This is necessary because it is possible that
             * the memory allocated to the Perl stack has been reallocated during
             * the *call_sv* call * SPAGAIN (no relation but makes me think of SPAGAghetti) */
            /* tux: this needs to be called because of side effects of call_sv() */
            SPAGAIN;
            ax = (SP - PL_stack_base) + 1;

            /* POPMARK maybe isn't needed? Find out if this is true or not */
            POPMARK;
        /* FREETMPS cleans up all stuff on the temporaries stack added since SAVETMPS was called */
        FREETMPS;
    /* Make like a tree and LEAVE */
    LEAVE;

    I32 sv_array_start = 0;
    I32 sv_array_end = myitems - 1;
    I32 sv_array_items = sv_array_end - sv_array_start + 1;
    /*for ( c = 0; c < myitems; c++) {
        sprintf(buf, "141 ST(%i)\n", c);
        PerlIO_puts(PerlIO_stderr(), buf);
        sv_dump(ST(c));
    }*/
    if (1) {
        EXTEND(SP, sv_array_items);
        for ( c = sv_array_end; sv_array_start <= c; c-- ) {
            //SvREFCNT_inc(sv_array[c]);
            //ST(c) = sv_array[myitems-1-c];
            /* There is probably a macro for the line below, but
             * I couldn't find it :( */
            //SV* mysv = sv_array[c] = *(mysp - c);
            I32 pos = myitems-1-c;
            if (my_debug) {
                sprintf(buf, "pushing sv_array[%i] to stack\n", pos);
                PerlIO_puts(PerlIO_stderr(), buf);
            }
            SV *mysv = sv_array[pos];
            if (my_debug) sv_dump(mysv);


            //sprintf(buf, "171: ST(%i)\n", from_start);
            //PerlIO_puts(PerlIO_stderr(), buf);
            //sv_dump(ST(from_start));

            //SvREFCNT_inc(mysv);
            mPUSHs(mysv);
            /* XPUSHs also extends by one (not needed?) */
            /*XPUSHs(sv_2mortal(sv_array[c])); */
        }
    }
    if (my_debug) {
        for ( c = 0; c < myitems; c++) {
            sprintf(buf, "163 ST(%i)\n", c);
            PerlIO_puts(PerlIO_stderr(), buf);
            //printf("160 ST(%i)\n", c);
            sv_dump(ST(c));
        }
    }
    /* Decrement the refcounts on what we passed to call_sv */
    for (c = sv_array_end; sv_array_start <= c; c--) {
        I32 from_start = sv_array_end - c;
        /*sprintf(buf, "171: ST(%i)\n", c);
        PerlIO_puts(PerlIO_stderr(), buf);
        sv_dump(ST(from_start));*/
        if (ST(c) != sv_array[c]) {
            warn("not the same\n");
        }
        //sv_dump(sv_array[c]);
        //SvREFCNT_dec(sv_array[c]);
        //sv_array[c] = NULL;
        /*printf("ref count of sv %i after: %i\n", i, SvREFCNT(sv_array[i])); */
    }
    for (c = 0; c < myitems; c++) {
        if (refcnts[c] != SvREFCNT(sv_array[c])) {
            sprintf(buf, "refcnts[%i] = %i but actually is %i\n", c, refcnts[c], SvREFCNT(sv_array[c]));
            PerlIO_puts(PerlIO_stderr(), buf);
        }
    }
    items = (I32)(SP - MARK);
    if (my_debug) {
        sprintf(buf, "items: %i\n", items);
        PerlIO_puts(PerlIO_stderr(), buf);
    }
    if (TOPs != save_tops) {
        PerlIO_puts(PerlIO_stderr(), "oh no tops");
    }


    return real_pp_func(aTHX);
}

PP(pp_overload_open) {
    return overload_allopen("open", "overload::open::GLOBAL", real_pp_open);
}

PP(pp_overload_sysopen) {
    return overload_allopen("sysopen", "overload::open::GLOBAL_TWO",
        real_pp_sysopen);
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
        SAVE_AND_REPLACE_PP_IF_UNSET(real_pp_open, OP_OPEN, Perl_pp_overload_open, OP_OPEN_replace_mutex);

void
_install_sysopen(what_you_want)
    char *what_you_want
    CODE:
        SAVE_AND_REPLACE_PP_IF_UNSET(real_pp_sysopen, OP_SYSOPEN, Perl_pp_overload_sysopen, OP_SYSOPEN_replace_mutex);
