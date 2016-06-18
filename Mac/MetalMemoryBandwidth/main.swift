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
    
    let defaultDevice : MTLDevice = MTLCreateSystemDefaultDevice()!;
    print("default device = ", defaultDevice);
    
    let commandQueue = defaultDevice.newCommandQueue();
    
    let commandBuffer = commandQueue.commandBuffer();
    
    let commandEncoder = commandBuffer.computeCommandEncoder();
    
    let myAdditionFunction: MTLFunction;
    
    let computePipelineState: MTLComputePipelineState?
    do {
        computePipelineState = try defaultDevice.newComputePipelineStateWithFunction(myAdditionFunction);
    }
    catch _ {
        print("error with compute pipeline state ...");
        return;
    }
    
    // 1. Call the setComputePipelineState(_:) method with the MTLComputePipelineState object that contains the compute function that will be executed.
    commandEncoder.setComputePipelineState(computePipelineState!);
    
    // WARNING: NOT DONE YET
    // 2 Specify resources that hold the input data (or output destination) for the compute function. Set the location (index) of each resource in its corresponding argument table.
    let resourceOptions: MTLResourceOptions = MTLResourceOptions(); // todo: this is probably messed up
    let arrayBuffer1 = defaultDevice.newBufferWithLength(N * 4, options: resourceOptions);
    let arrayBuffer2 = defaultDevice.newBufferWithLength(N * 4, options: resourceOptions);
    let sumBuffer = defaultDevice.newBufferWithLength(N * 4, options: resourceOptions);

    commandEncoder.setBuffer(arrayBuffer1, offset: 0, atIndex: 0);
    commandEncoder.setBuffer(arrayBuffer2, offset: 0, atIndex: 1);
    commandEncoder.setBuffer(sumBuffer, offset: 0, atIndex: 2);

    // 3. Call the dispatchThreadgroups(_:threadsPerThreadgroup:) method to encode the compute function with a specified number of threadgroups for the grid and the number of threads per threadgroup.
    let threadsPerThreadgroup: MTLSize = MTLSizeMake(256, 1, 1); // a decent guess
    commandEncoder.dispatchThreadgroups(MTLSizeMake(N / threadsPerThreadgroup.width, 1, 1), threadsPerThreadgroup: threadsPerThreadgroup)
    
    // 4. Call endEncoding() to finish encoding the compute commands onto the command buffer.
    commandEncoder.endEncoding();
    
    
    commandBuffer.enqueue();
    commandBuffer.commit(); // causes the command buffer to be executed as soon as possible
    
    print("command buffer committed");
    
    commandBuffer.waitUntilScheduled();

    print("command buffer scheduled");
    
    commandBuffer.waitUntilCompleted();
    
    print("command buffer complete.");
    if (commandBuffer.status == MTLCommandBufferStatus.Error) {
        if (commandBuffer.error != nil) {
            print("command buffer failed with error: ", commandBuffer.error)
        }
        else {
            print("command buffer failed")
        }
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