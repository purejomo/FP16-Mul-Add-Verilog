# FP16-Mul-Add-Verilog

A comprehensive Verilog implementation of 16-bit floating point arithmetic operations including multiplication and addition with both combinational and pipelined architectures.

## Overview

This project implements IEEE 754 half-precision (FP16) floating point arithmetic operations in Verilog. It provides both combinational and pipelined versions of floating point multiplication and addition, designed for high-performance digital signal processing and machine learning applications.

## Features

- **FP16 Multiplication**: Both combinational and pipelined implementations
- **FP16 Addition**: Both combinational and pipelined implementations  
- **IEEE 754 Compliance**: Proper handling of special values (NaN, Infinity, Zero)
- **Error Detection**: Overflow, underflow, and precision loss flags
- **Pipeline Architecture**: High-throughput pipelined designs for performance-critical applications
- **Comprehensive Testing**: Extensive testbenches and verification scripts

## Project Structure

```
FP16-Mul-Add-Verilog/
├── Sources/                    # Verilog source files
│   ├── float_multi.v         # Combinational FP16 multiplier
│   ├── float_multi_pipelined_v2.v  # Pipelined FP16 multiplier (v2)
│   ├── float_adder.v         # Combinational FP16 adder
│   └── float_adder_pipelined.v    # Pipelined FP16 adder
├── Simulation/                # Testbench files
│   ├── float_multi_pipelined_tb.v
│   ├── float_adder_pipelined_tb.v
│   ├── float_multi_sim.v
│   ├── float_add_sim.v
│   └── operatorCore_sim.v
├── Scripts/                   # Python verification scripts
│   ├── binary16_split.py
│   ├── binary16_verify_hex.py
│   └── binary16_verify.py
└── Test/                     # Test files and results
```

## Module Descriptions

### Multiplication Modules

#### `float_multi` (Combinational)
- **Purpose**: Combinational FP16 multiplication
- **Latency**: 1 cycle (combinational)
- **Features**: Full IEEE 754 compliance with proper rounding

#### `float_multi_pipelined_v2` (Pipelined)
- **Purpose**: High-performance pipelined FP16 multiplication
- **Latency**: Multiple pipeline stages
- **Features**: Optimized for high-throughput applications

### Addition Modules

#### `float_adder` (Combinational)
- **Purpose**: Combinational FP16 addition
- **Latency**: 1 cycle (combinational)
- **Features**: Proper handling of denormalized numbers

#### `float_adder_pipelined` (Pipelined)
- **Purpose**: High-performance pipelined FP16 addition
- **Latency**: Multiple pipeline stages
- **Features**: Optimized for high-throughput applications

## Interface

### Common Ports

```verilog
// Inputs
input wire        clk,        // Clock (pipelined modules only)
input wire        rstn,       // Active-low reset (pipelined modules only)
input wire        valid_in,   // Input valid signal (pipelined modules only)
input wire [15:0] num1,       // First operand
input wire [15:0] num2,       // Second operand

// Outputs
output reg        valid_out,  // Output valid signal (pipelined modules only)
output reg [15:0] result,     // Result
output reg        overflow,   // Overflow flag
output reg        zero,       // Zero result flag
output reg        NaN,        // Not a Number flag
output reg        precisionLost // Precision loss flag
```

## FP16 Format

The implementation uses IEEE 754 half-precision format:
- **Sign bit**: 1 bit (bit 15)
- **Exponent**: 5 bits (bits 14:10), bias = 15
- **Mantissa**: 10 bits (bits 9:0)

## Usage Examples

### Combinational Multiplication
```verilog
float_multi multiplier (
    .num1(16'h3C00),  // 1.0 in FP16
    .num2(16'h4000),  // 2.0 in FP16
    .result(result),
    .overflow(overflow),
    .zero(zero),
    .NaN(NaN),
    .precisionLost(precisionLost)
);
```

### Pipelined Addition
```verilog
float_adder_pipelined adder (
    .clk(clk),
    .rstn(rstn),
    .valid_in(valid_in),
    .num1(16'h3C00),  // 1.0 in FP16
    .num2(16'h4000),  // 2.0 in FP16
    .valid_out(valid_out),
    .result(result),
    .overflow(overflow),
    .zero(zero),
    .NaN(NaN),
    .precisionLost(precisionLost)
);
```

## Simulation and Testing

### Running Simulations

1. **Compile the design**:
```bash
iverilog -o testbench.vvp testbench.v float_multi.v
```

2. **Run simulation**:
```bash
vvp testbench.vvp
```

3. **View waveforms** (if using GTKWave):
```bash
gtkwave testbench.vcd
```

### Verification Scripts

The project includes Python scripts for verification:
- `binary16_verify.py`: General FP16 verification
- `binary16_verify_hex.py`: Hexadecimal input verification
- `binary16_split.py`: Binary format conversion utilities

## Performance Characteristics

### Combinational Modules
- **Latency**: 1 cycle
- **Throughput**: 1 operation per cycle
- **Area**: Optimized for minimal resource usage

### Pipelined Modules
- **Latency**: Multiple cycles (varies by implementation)
- **Throughput**: 1 operation per cycle (after pipeline fill)
- **Area**: Optimized for high-frequency operation

## Special Value Handling

The implementation properly handles IEEE 754 special values:
- **Zero**: Both positive and negative zero
- **Infinity**: Both positive and negative infinity
- **NaN**: Not a Number with proper propagation
- **Denormalized numbers**: Subnormal number support

## Error Detection

Each module provides comprehensive error detection:
- **Overflow**: Result exceeds maximum representable value
- **Underflow**: Result is smaller than minimum representable value
- **Precision Loss**: Rounding or truncation occurred
- **NaN**: Invalid operation detected

## Applications

This implementation is suitable for:
- **Machine Learning**: Neural network inference accelerators
- **Digital Signal Processing**: High-performance DSP applications
- **Scientific Computing**: Floating point intensive calculations
- **GPU/TPU Design**: Arithmetic units for specialized processors

## Requirements

- **Synthesis Tools**: Compatible with most Verilog synthesis tools
- **Simulation**: Icarus Verilog, ModelSim, or similar
- **Python**: For verification scripts (Python 3.x)

## License

See LICENSE file for licensing information.

## Contributing

Contributions are welcome! Please ensure:
- Code follows Verilog best practices
- Testbenches are comprehensive
- Documentation is updated
- All tests pass before submission

## Contact

For questions or issues, please refer to the project documentation or create an issue in the repository.
