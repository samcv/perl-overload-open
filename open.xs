#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#define SAVE_AND_REPLACE_PP_IF_UNSET(real_function, op_to_replace, overload_function) do {\
    if (PL_ppaddr[op_to_replace] != overload_function) {\
        /* Is this a race in threaded perl? */\
        real_function = PL_ppaddr[op_to_replace];\
        PL_ppaddr[op_to_replace] = overload_function;\
    }\
    else {\
        /* Would be nice if we could warn here. */\
    }\
} while (0)
#define overload_open_max_function_pointers 2
OP* (*stuff_array[overload_open_max_function_pointers])(pTHX);
/* Declare function pointers for OP's */
OP* (*real_pp_open)(pTHX) = NULL;
OP* (*real_pp_sysopen)(pTHX) = NULL;
#define overload_open_max_args 99
PP(pp_overload_open) {
    dSP; dTARG;
    SV *hook, *sv;
    SV *sv_array[overload_open_max_args];
    I32 count, ax, my_debug = 0, my_topmark_after, i;
    /* hook is what we are calling instead of `open` */
    /* This is probably going to be the slowest part of the code
     * Think about caching this or provide an API to set it */
    hook = get_sv("overload::open::GLOBAL", 0);
    if ( !SvPOK( hook ) ) {
        return real_pp_open(aTHX);
    }

    if (my_debug) {
        printf("TOPs before ENTER\n");
        sv_dump(TOPs);
        printf("TOPm1s before ENTER\n");
        sv_dump(TOPm1s);
    }
    int sv_array_pos = 0;
    /* Top of stack contains the last argument to open() */
    sv = TOPs;
    /* Increase the ref count for sv. This may not actually be needed
     * but let's do it just in case.
     * TODO: can this cause memory leaks in case of an exception? (is there any
     * way that SvREFCNT_dec won't be called at the bottom of the function? */
    SvREFCNT_inc(sv);

    ENTER;
        /* Save the temporaries stack */
        SAVETMPS;
            /* Marking has to do with getting the number of arguments ?
            * maybe. pushmark is start of the arguments */
            /* The value stack stores individual perl scalar values as temporaries between
            expressions. Some perl expressions operate on entire lists; for that purpose
            we need to know where on the stack each list begins. This is the purpose of the
            mark stack. */
            PUSHMARK(SP); /* SP = Stack Pointer. */
                /* Ensure there is enough room to push $TOPMARK number onto stack */
                EXTEND(SP, TOPMARK);
                my_topmark_after = TOPMARK;
                if (overload_open_max_args < my_topmark_after) {
                    my_topmark_after = overload_open_max_args;
                }
                /* Push to the value stack */
                for (i = 1; i < my_topmark_after ; i++) {
                    sv_array[sv_array_pos++] = ST(i);
                    SvREFCNT_inc(ST(i));
                    if (my_debug) {
                        printf("arg %i\n", i);
                        sv_dump(ST(i));
                    }
                }
                sv_array[sv_array_pos++] = sv;
                for (i = 0; i < sv_array_pos; i++) {
                    XPUSHs(sv_array[i]);
                }
            PUTBACK; /* Closing bracket for XSUB arguments */
            /* count is the number of arguments returned from the call. call_sv()
             * call calls the function `hook` */
            count = call_sv( hook, G_VOID | G_DISCARD );
            /* G_VOID and G_DISCARD should cause us to not ask for any return
             * arguments from the call. */
            if (count) {
                /* This should really never happen. Put a warn in there because */
                warn("call_sv was not supposed to get any arguments");
            }
            /* SPAGAIN (no relation but makes me think of SPAGAghetti) */
            /* SPAGAIN refetch the stack pointer.  Used after a callback. */
            SPAGAIN;
            /* POPMARK maybe isn't needed? Find out if this is true or not */
            //POPMARK;
            /* FREETMPS cleans up all stuff on the temporaries stack added since SAVETMPS was called */
        FREETMPS;
    /* Make like a tree and LEAVE */
    LEAVE;
    /* Decrement the refcounts on what we passed to call_sv */
    for (i = 0; i < sv_array_pos; i++) {
        SvREFCNT_dec(sv_array[i]);
    }
    if (my_debug) {
        sv_dump(TOPs);
        sv_dump(TOPm1s);
    }
    return real_pp_open(aTHX);
}

MODULE = overload::open	PACKAGE = overload::open PREFIX = overload_open_

PROTOTYPES: ENABLE

void
_install_open(what_you_want)
    char *what_you_want
    CODE:
        if (strcmp(what_you_want, "OP_OPEN") == 0) {
            SAVE_AND_REPLACE_PP_IF_UNSET(real_pp_open, OP_OPEN, Perl_pp_overload_open);
        }
        else if (strcmp(what_you_want, "OP_SYSOPEN") == 0) {
            SAVE_AND_REPLACE_PP_IF_UNSET(real_pp_sysopen, OP_SYSOPEN, Perl_pp_overload_open);
        }
        /* Just default to this */
        else {
            SAVE_AND_REPLACE_PP_IF_UNSET(real_pp_open, OP_OPEN, Perl_pp_overload_open);
        }

