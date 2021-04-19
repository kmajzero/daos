/**
 * (C) Copyright 2016-2021 Intel Corporation.
 *
 * SPDX-License-Identifier: BSD-2-Clause-Patent
 */
/**
 * Object placement policy
 *  Type and global declarations
 *
 * Author: Krzysztof Majzerowicz-Jaszcz (krzysztof.majzerowicz-jaszcz@intel.com)
 */

#ifndef __VOS_POLICY_H__
#define __VOS_POLICY_H__

#include <daos/common.h>

#include "vos_internal.h"

#define VOS_POLICY_OPTANE_SHIFT     (16)  /* 64k */
#define VOS_POLICY_OPTANE_THRESHOLD (1ULL << VOS_POLICY_OPTANE_SHIFT)

#define VOS_POLICY_SCM_SHIFT        (12)  /* 4k */
#define VOS_POLICY_SCM_THRESHOLD    (1ULL << VOS_POLICY_SCM_SHIFT)

daos_media_type_t
vos_policy_media_select(struct vos_pool *pool, daos_iod_type_t type,
                        daos_size_t size);



#endif /* __VOS_POLICY_H__ */