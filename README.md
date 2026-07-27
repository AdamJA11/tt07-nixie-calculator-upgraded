Upgraded 963 Nixie Calculator (Tiny Tapeout 07)
This project is an advanced, upgraded implementation of the original "963 Calculator" designed for the Tiny Tapeout 07 platform. The core objective of this fork was to take a functional baseline design and significantly enhance its arithmetic capabilities, error handling, and visual ergonomics while successfully passing the strict physical synthesis constraints of the open-source LibreLane ASIC flow (SkyWater 130nm).

🚀 Upgraded Architecture & Hardware Enhancements
The original architecture was limited to basic integer operations and a restricted data bus. This upgraded version introduces several major hardware modifications to transform the macro into a more robust and versatile digital processor:

11-Bit Internal Bus Extension: The internal combinational datapath was expanded from 10 to 11 bits. This critical modification prevents the sign bit from being overwritten during overflow conditions (e.g., additions exceeding 511), ensuring mathematical stability.

Hardware Exceptions ("E r r"): Implementation of a dedicated hardware trapping mechanism. If a calculation result exceeds the maximum displayable threshold (999), the normal BCD decoder is automatically bypassed to synchronously display an "E r r" visual alert on the multiplexed Nixie tubes.

ALU DSP & Modifier Modes: Integration of advanced DSP-like functions directly accessible via a hardware switch modifier. Without adding heavy logic gates (zero-gate cost approach via spatial routing), the ALU now supports:

Division by 16 (Bit shifting).

Magnitude Comparison.

Bit Mirroring operations.

Fixed-Point Decimal Mode (Float): Dynamic reallocation of the internal data bus to support calculations with a precision of one decimal digit (tenths), activating the previously unused fourth Nixie tube.

Static Negative Indicator: A hardware-level two's complement conversion system that automatically detects negative results and drives a dedicated static minus sign ("-") on the leftmost Nixie tube, providing a clear and reliable alert for negative arithmetic.

🛠️ Physical Implementation (LibreLane / SKY130)
This upgraded design was successfully synthesized and routed using the modern LibreLane flow. Due to the addition of complex combinational steering logic for the Float mode and hardware exception handling, the initial physical placement failed under default constraints.

To achieve successful physical closure, the config.json was adjusted:

Target Density was increased to 65% (PL_TARGET_DENSITY_PCT = 65).

Global Routing Congestion tolerances were optimized (GRT_ALLOW_CONGESTION = true).

Final Sign-off: The layout passes all LVS, DRC, and Antenna checks with 0 manufacturing defects on a standard 80x80µm die area.

🧪 Verification & Simulation
The design behavior is strictly validated using a modern Cocotb (Python) and Icarus Verilog testbench environment.

Total Test Cases: 15 independent functional routines covering both integer and fixed-point domains.

Coverage: 100% Pass rate.

Waveform Analysis: Validated via GTKWave, confirming perfect temporal multiplexing (no display ghosting) and strict signal enforcement for the 14-bit cathode buses.

📁 Repository Structure
src/: Contains the upgraded SystemVerilog/Verilog RTL files.

test/: Contains the Cocotb testing infrastructure (test.py and Makefile).

config.json: The specific LibreLane environment constraints tailored for this layout.

*Developed for academic evaluation in microelectronics and digital ASIC design.*
