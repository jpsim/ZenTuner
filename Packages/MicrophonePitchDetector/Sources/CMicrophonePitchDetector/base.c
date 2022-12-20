// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "CMicrophonePitchDetector.h"

void zt_auxdata_alloc(zt_auxdata *aux, size_t size)
{
    aux->ptr = malloc(size);
    aux->size = size;
    memset(aux->ptr, 0, size);
}

void zt_auxdata_free(zt_auxdata *aux)
{
    free(aux->ptr);
}
