#include <stdio.h>
#include <stdint.h>
#include <math.h>

// FP16 structure
typedef union {
    uint16_t bits;
    struct {
        uint16_t frac : 10;
        uint16_t exp : 5;
        uint16_t sign : 1;
    } parts;
} fp16_t;

// Convert FP16 to double for calculation
double fp16_to_double(fp16_t fp16) {
    if (fp16.parts.exp == 0) {
        if (fp16.parts.frac == 0) {
            return fp16.parts.sign ? -0.0 : 0.0;
        } else {
            // Subnormal
            return (fp16.parts.sign ? -1.0 : 1.0) * pow(2, -14) * (fp16.parts.frac / 1024.0);
        }
    } else if (fp16.parts.exp == 31) {
        if (fp16.parts.frac == 0) {
            return fp16.parts.sign ? -INFINITY : INFINITY;
        } else {
            return NAN;
        }
    } else {
        // Normal
        return (fp16.parts.sign ? -1.0 : 1.0) * pow(2, fp16.parts.exp - 15) * (1.0 + fp16.parts.frac / 1024.0);
    }
}

// Convert double to FP16
fp16_t double_to_fp16(double val) {
    fp16_t result = {0};
    
    if (val == 0.0) {
        return result; // +0
    } else if (val == -0.0) {
        result.parts.sign = 1;
        return result; // -0
    } else if (isinf(val)) {
        result.parts.exp = 31;
        result.parts.sign = (val < 0) ? 1 : 0;
        return result;
    } else if (isnan(val)) {
        result.parts.exp = 31;
        result.parts.frac = 1;
        return result;
    }
    
    int sign = (val < 0) ? 1 : 0;
    val = fabs(val);
    
    if (val < pow(2, -14)) {
        // Subnormal
        result.parts.sign = sign;
        result.parts.exp = 0;
        result.parts.frac = (uint16_t)(val * pow(2, 14) * 1024);
    } else {
        // Normal
        int exp = (int)floor(log2(val)) + 15;
        if (exp < 0) exp = 0;
        if (exp > 30) exp = 31;
        
        result.parts.sign = sign;
        result.parts.exp = exp;
        result.parts.frac = (uint16_t)((val / pow(2, exp - 15) - 1.0) * 1024);
    }
    
    return result;
}

// FP16 multiplication with detailed debug output
fp16_t fp16_multiply_debug(fp16_t a, fp16_t b) {
    printf("\n=== FP16 Multiply Debug ===\n");
    printf("Input A: 0x%04x = %.10f (sign=%d, exp=%d, frac=0x%03x)\n", 
           a.bits, fp16_to_double(a), a.parts.sign, a.parts.exp, a.parts.frac);
    printf("Input B: 0x%04x = %.10f (sign=%d, exp=%d, frac=0x%03x)\n", 
           b.bits, fp16_to_double(b), b.parts.sign, b.parts.exp, b.parts.frac);
    
    // Handle special cases
    if (a.parts.exp == 31 || b.parts.exp == 31) {
        printf("Special case: Infinity or NaN\n");
        if ((a.parts.exp == 31 && a.parts.frac != 0) || (b.parts.exp == 31 && b.parts.frac != 0)) {
            // NaN
            fp16_t result = {0};
            result.parts.exp = 31;
            result.parts.frac = 1;
            return result;
        } else if ((a.parts.exp == 31 && a.parts.frac == 0) || (b.parts.exp == 31 && b.parts.frac == 0)) {
            // Infinity
            fp16_t result = {0};
            result.parts.sign = a.parts.sign ^ b.parts.sign;
            result.parts.exp = 31;
            return result;
        }
    }
    
    if ((a.parts.exp == 0 && a.parts.frac == 0) || (b.parts.exp == 0 && b.parts.frac == 0)) {
        printf("Special case: Zero\n");
        fp16_t result = {0};
        result.parts.sign = a.parts.sign ^ b.parts.sign;
        return result;
    }
    
    // Normal multiplication
    double val_a = fp16_to_double(a);
    double val_b = fp16_to_double(b);
    double exact_result = val_a * val_b;
    
    printf("Exact multiplication: %.10f * %.10f = %.10f\n", val_a, val_b, exact_result);
    
    fp16_t result = double_to_fp16(exact_result);
    
    printf("FP16 result: 0x%04x = %.10f (sign=%d, exp=%d, frac=0x%03x)\n", 
           result.bits, fp16_to_double(result), result.parts.sign, result.parts.exp, result.parts.frac);
    
    return result;
}

int main() {
    printf("FP16 Multiplication Reference Implementation\n");
    printf("==========================================\n");
    
    // Test case 1: 0x4689 * 0x0025
    fp16_t a1 = {0x4689};
    fp16_t b1 = {0x0025};
    fp16_t result1 = fp16_multiply_debug(a1, b1);
    printf("Test 1: 0x%04x * 0x%04x = 0x%04x (expected: 0x00f2)\n", a1.bits, b1.bits, result1.bits);
    
    // Test case 2: 0x4489 * 0x001d
    fp16_t a2 = {0x4489};
    fp16_t b2 = {0x001d};
    fp16_t result2 = fp16_multiply_debug(a2, b2);
    printf("Test 2: 0x%04x * 0x%04x = 0x%04x (expected: 0x0084)\n", a2.bits, b2.bits, result2.bits);
    
    return 0;
}
