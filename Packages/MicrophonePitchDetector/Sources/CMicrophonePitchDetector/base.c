// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "CMicrophonePitchDetector.h"

int zt_create(zt_data **spp)
{
    *spp = (zt_data *) malloc(sizeof(zt_data));
    zt_data *sp = *spp;
    ZTFLOAT *out = malloc(sizeof(ZTFLOAT));
    *out = 0;
    sp->out = out;
    sp->sr = 44100;
    sp->len = 5 * sp->sr;
    sp->pos = 0;
    return 0;
}

int zt_destroy(zt_data **spp)
{
    zt_data *sp = *spp;
    free(sp->out);
    free(*spp);
    return 0;
}

int zt_auxdata_alloc(zt_auxdata *aux, size_t size)
{
    aux->ptr = malloc(size);
    aux->size = size;
    memset(aux->ptr, 0, size);
    return ZT_OK;
}

int zt_auxdata_free(zt_auxdata *aux)
{
    free(aux->ptr);
    return ZT_OK;
}
