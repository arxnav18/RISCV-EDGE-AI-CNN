import numpy as np

def conv2d_3x3(input_mat, kernel):
    """
    Performs a 2D convolution with a 3x3 kernel on the input matrix.
    No padding, stride 1.
    """
    in_h, in_w = input_mat.shape
    out_h = in_h - 2
    out_w = in_w - 2
    
    if out_h <= 0 or out_w <= 0:
        return np.array([])

    output_mat = np.zeros((out_h, out_w), dtype=np.int32)
    
    for i in range(out_h):
        for j in range(out_w):
            window = input_mat[i:i+3, j:j+3]
            # Element-wise multiplication and sum (MAC operation)
            mac_sum = np.sum(window * kernel)
            output_mat[i, j] = mac_sum
            
    return output_mat

def test_convolution_pipeline(test_name, input_image, kernels):
    print(f"\\n{'='*50}")
    print(f" Test Case: {test_name}")
    print(f" {'='*50}")
    
    print("\\n[Input Image] (8x8):")
    print(input_image)
    
    # Layer 1
    print("\\n--- Conv Unit 1 ---")
    print("Kernel 1:")
    print(kernels[0])
    feature_map_1 = conv2d_3x3(input_image, kernels[0])
    print("\\nFeature Map 1 Output (6x6):")
    print(feature_map_1)
    
    # Layer 2
    print("\\n--- Conv Unit 2 ---")
    print("Kernel 2:")
    print(kernels[1])
    feature_map_2 = conv2d_3x3(feature_map_1, kernels[1])
    print("\\nFeature Map 2 Output (4x4):")
    print(feature_map_2)
    
    # Layer 3
    print("\\n--- Conv Unit 3 ---")
    print("Kernel 3:")
    print(kernels[2])
    feature_map_3 = conv2d_3x3(feature_map_2, kernels[2])
    print("\\nFeature Map 3 Output (Final 2x2):")
    print(feature_map_3)
    print(f"{'='*50}\\n")

def main():
    # Test 1: Identity/Edge Detection Kernel Test
    img_1 = np.arange(1, 65).reshape((8, 8))
    
    # Identity kernel: just center pixel
    k_id = np.array([
        [0, 0, 0],
        [0, 1, 0],
        [0, 0, 0]
    ])
    
    # Edge detection kernel (simple laplacian)
    k_edge = np.array([
        [ 0, -1,  0],
        [-1,  4, -1],
        [ 0, -1,  0]
    ])
    
    # Blur kernel (uniform)
    k_blur = np.ones((3,3), dtype=np.int32)
    
    test_convolution_pipeline("Sequential Filters (Id -> Edge -> Blur)", img_1, [k_id, k_edge, k_blur])

    # Test 2: Random Values
    np.random.seed(42)
    img_2 = np.random.randint(-5, 5, size=(8, 8))
    k1 = np.random.randint(-2, 3, size=(3, 3))
    k2 = np.random.randint(-2, 3, size=(3, 3))
    k3 = np.random.randint(-2, 3, size=(3, 3))
    
    test_convolution_pipeline("Random Weights & Data", img_2, [k1, k2, k3])

if __name__ == "__main__":
    main()
