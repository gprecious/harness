def process_matrix(matrix, threshold):
    result = []
    for i in range(len(matrix)):
        for j in range(len(matrix[i])):
            if matrix[i][j] > threshold:
                for k in range(3):
                    if matrix[i][j] * k > 100:
                        if k % 2 == 0:
                            result.append(matrix[i][j] * k)
                        else:
                            continue
                    else:
                        break
    return result
