//
//  main.swift
//  MetalMemoryBandwidth
//
//  Created by Holmes Futrell on 6/17/16.
//  Copyright © 2016 Holmes Futrell. All rights reserved.
//

import Foundation
import MetalKit

func randomFloat() -> Float {
    return Float(arc4random()) / Float(UINT32_MAX);
}

func computeSumCPU(array1 array1 : [Float], array2 : [Float], inout sumArray : [Float], N : Int) {
    for i in 0..<N {
        sumArray[i] = array1[i] + array2[i];
    }
}

func computeSumMetal(array1 array1 : [Float], array2 : [Float], inout sumArray : [Float], N : Int) {
    
    let devices: [MTLDevice] = MTLCopyAllDevices();
    for device in devices {
        print(device);
    }
    
}

// create an array of random floats

var N : Int = 1024 * 1024;

print("Running test with N = ", N);

var floatArray1 = [Float](count: N, repeatedValue: 0.0);
var floatArray2 = [Float](count: N, repeatedValue: 0.0);
var sumArray = [Float](count: N, repeatedValue: 0.0);

for i in 0..<N {
    floatArray1[i] = randomFloat();
}
for i in 0..<N {
    floatArray2[i] = randomFloat();
}

// compute sum

computeSumMetal(array1: floatArray1, array2: floatArray2, sumArray: &sumArray, N: N);

// verify sum

var success = true;
for i in 0..<N {
    if sumArray[i] != floatArray1[i] + floatArray2[i] {
        print("sum failed at index", i);
        success = false;
        break;
    }
}

if success {
    print("success");
}