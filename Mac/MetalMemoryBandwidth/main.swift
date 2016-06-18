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

func generateLibrary(device: MTLDevice) -> MTLLibrary {
    let library : MTLLibrary?;
    do {
        let source : String = try String(contentsOfFile: "./addFunction.metal" )
        library = try device.newLibraryWithSource(source, options: nil) // do we need compile options?
    }
    catch _ {
        print("error creating library ...");
        library = nil
    }
    return library!
}

func computeSumMetal(array1 array1 : [Float], array2 : [Float], inout sumArray : [Float], N : Int) {
    
    let devices: [MTLDevice] = MTLCopyAllDevices();
    for device in devices {
        print(device);
    }
    
    let defaultDevice : MTLDevice = MTLCreateSystemDefaultDevice()!;
    print("default device = ", defaultDevice);
    
    // create the buffers
    let resourceOptions: MTLResourceOptions = MTLResourceOptions.StorageModeManaged
    let arrayBuffer1 = defaultDevice.newBufferWithBytes(array1, length: N * sizeof(Float), options: resourceOptions)
    let arrayBuffer2 = defaultDevice.newBufferWithBytes(array2, length: N * sizeof(Float), options: resourceOptions)
    let sumBuffer = defaultDevice.newBufferWithBytes(sumArray, length: N * sizeof(Float), options: resourceOptions)
    
    // create the library
    let library: MTLLibrary = generateLibrary(defaultDevice)
    let myAdditionFunction: MTLFunction = library.newFunctionWithName("myAddFunction")!;
    
    // create compute pipeline state
    let computePipelineState: MTLComputePipelineState?
    do {
        computePipelineState = try defaultDevice.newComputePipelineStateWithFunction(myAdditionFunction);
    }
    catch _ {
        print("error with compute pipeline state ...");
        return;
    }

    let commandQueue = defaultDevice.newCommandQueue();
    
    let threadsPerThreadgroup: MTLSize = MTLSizeMake(256, 1, 1) // a decent guess
    let threadGroups: MTLSize = MTLSizeMake(N / threadsPerThreadgroup.width, 1, 1)
    
    print("generating command buffers ...")
    
    let timeStart = NSDate()
    let generateCommandBuffersStart: NSDate = NSDate()
    
    let iterations = 500
    var lastCommandBuffer: MTLCommandBuffer? = nil
    for i in 0..<iterations {
        
        let commandBuffer = commandQueue.commandBuffer();
        let commandEncoder = commandBuffer.computeCommandEncoder();
        
        // 1. Call the setComputePipelineState(_:) method with the MTLComputePipelineState object that contains the compute function that will be executed.
        commandEncoder.setComputePipelineState(computePipelineState!);
        
        // 2 Specify resources that hold the input data (or output destination) for the compute function. Set the location (index) of each resource in its corresponding argument table.
        commandEncoder.setBuffer(arrayBuffer1, offset: 0, atIndex: 0);
        commandEncoder.setBuffer(arrayBuffer2, offset: 0, atIndex: 1);
        commandEncoder.setBuffer(sumBuffer, offset: 0, atIndex: 2);

        // 3. Call the dispatchThreadgroups(_:threadsPerThreadgroup:) method to encode the compute function with a specified number of threadgroups for the grid and the number of threads per threadgroup.
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
        
        // 4. Call endEncoding() to finish encoding the compute commands onto the command buffer.
        commandEncoder.endEncoding();
        
        commandBuffer.enqueue();
        
        if ( i == iterations-1) {
            lastCommandBuffer = commandBuffer
            // last command buffer gets a blit encoder
            // to synchronize on the sum memory
            // otherwise the CPU can't read it
            let blitCommandEncoder = commandBuffer.blitCommandEncoder()
            blitCommandEncoder.synchronizeResource(sumBuffer)
            blitCommandEncoder.endEncoding();
        }
        
        commandBuffer.commit(); // causes the command buffer to be executed as soon as possible
        commandBuffer.waitUntilScheduled()
        
    }
    
    print("took ", NSDate().timeIntervalSinceDate(generateCommandBuffersStart), " seconds");
    
    lastCommandBuffer!.waitUntilCompleted();
    print("command buffer complete.");
    
    if (lastCommandBuffer!.status == MTLCommandBufferStatus.Error) {
        if (lastCommandBuffer!.error != nil) {
            print("command buffer failed with error: ", lastCommandBuffer!.error)
        }
        else {
            print("command buffer failed")
            
        }
        return
    }
    
    let timeInterval: Double = NSDate().timeIntervalSinceDate(timeStart)
    let bytesPerSecond : Double = (Double(iterations * 3 * N * sizeof(Float))) / Double(timeInterval)
    let gBytesPerSecond : Double = bytesPerSecond / 1024.0 / 1024.0 / 1024.0
    
    print("took ", timeInterval, " seconds")
    print("bytes per second: ", bytesPerSecond)
    print("GB per second: ", gBytesPerSecond)

    
    let output : UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(sumBuffer.contents())
    sumArray = Array(UnsafeBufferPointer(start: output, count: N));
    
}

// create an array of random floats

var N : Int = 1024 * 1024 * 32;

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
        print("sum failed at index", i, "(got ", sumArray[i], ", expected ", floatArray1[i] + floatArray2[i], ")");
        success = false;
        break;
    }
}

if success {
    print("success");
}