import numpy as np

def run_3d_convolution():
    print("--- 3D Convolution Reference Model ---")
    
    # Example config matching hardware test
    input_width = 8
    input_height = 8
    channels = 3
    kernel_size = 3
    num_filters = 1
    
    # 1. Create a dummy test image (all 1s)
    image = np.ones((input_height, input_width, channels), dtype=np.int32)
    
    # 2. Create dummy weights (all 1s)
    # Shape: (kernel_height, kernel_width, in_channels, out_filters)
    weights = np.ones((kernel_size, kernel_size, channels, num_filters), dtype=np.int32)
    
    # Calculate output dimensions
    out_height = input_height - kernel_size + 1
    out_width = input_width - kernel_size + 1
    
    # Output feature map
    output_map = np.zeros((out_height, out_width, num_filters), dtype=np.int32)
    
    # Perform standard convolution (Valid padding)
    print("Running Convolution...")
    for f in range(num_filters):
        for y in range(out_height):
            for x in range(out_width):
                # Extract 3D window
                window = image[y:y+kernel_size, x:x+kernel_size, :]
                kernel = weights[:, :, :, f]
                
                # Perform MAC
                mac_result = np.sum(window * kernel)
                output_map[y, x, f] = mac_result
                
    print(f"Convolution Output Shape: {output_map.shape}")
    print("Sample Output at (0,0,0):")
    print(output_map[0, 0, 0])
    
    # Verify mathematically
    # Window = 3x3x3 = 27 elements. All 1s multiplied by all 1s = sum of 27 = 27
    expected_val = kernel_size * kernel_size * channels
    if output_map[0, 0, 0] == expected_val:
        print(f"PASS: Python Output Matches Expected Result ({expected_val})")
    else:
        print(f"FAIL: Expected {expected_val}, Got {output_map[0, 0, 0]}")

if __name__ == "__main__":
    run_3d_convolution()
