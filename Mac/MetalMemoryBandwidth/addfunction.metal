//
//  addfunction.metal
//  MetalMemoryBandwidth
//
//  Created by Holmes Futrell on 6/18/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void

myAddFunction(device float *array1, device float *array2, device float *sum, uint id [[ thread_position_in_grid ]] ) {
    sum[id] = array1[id] + array2[id];
}