import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

# --- FONCTION D'AIDE : SAISIE D'UN NOMBRE SUR 9 BITS ---
async def set_number(dut, is_B, value):
    """
    is_B = 0 pour numA, 1 pour numB
    value = entier entre 0 et 511 (9 bits max)
    """
    bit8 = (value >> 8) & 1           
    bits7_4 = (value >> 4) & 0xF      
    bits3_0 = value & 0xF             

    ui_val_haut = (0 << 7) | (bit8 << 6) | (0 << 5) | (is_B << 4) | bits7_4
    dut.ui_in.value = ui_val_haut
    await ClockCycles(dut.clk, 2) 

    ui_val_bas = (0 << 7) | (bit8 << 6) | (1 << 5) | (is_B << 4) | bits3_0
    dut.ui_in.value = ui_val_bas
    await ClockCycles(dut.clk, 2)

# --- FONCTION D'AIDE : DÉCLENCHEMENT D'UNE OPÉRATION ---
async def do_operation(dut, op_name, shift_button=0):
    ops = {
        'A':   [1, 0, 0, 0, 0],
        'B':   [0, 0, 0, 0, 0], 
        'ADD': [0, 1, 0, 0, 0],
        'AND': [0, 0, 1, 0, 0],
        'OR':  [0, 0, 0, 1, 0],
        'XOR': [0, 0, 0, 0, 1]
    }
    
    sign, add, and_, or_, xor = ops[op_name]
    pos_b = 1 if (op_name == 'B' or shift_button == 1) else 0

    ui_val = (1 << 7) | (sign << 6) | (pos_b << 5) | (0 << 4) | (add << 3) | (and_ << 2) | (or_ << 1) | xor
    dut.ui_in.value = ui_val
    await Timer(1, units="us") 
    
    return int(dut.user_project.keyboardreal.ans.value) 

# =======================================================================
# 1. TEST DE L'ALU CLASSIQUE (Existant)
# =======================================================================
@cocotb.test()
async def test_alu_basic(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    await set_number(dut, 0, 10) 
    await set_number(dut, 1, 6)  

    assert await do_operation(dut, 'ADD') == 16
    assert await do_operation(dut, 'AND') == 2
    assert await do_operation(dut, 'OR') == 14

# =======================================================================
# 2. TEST DES FONCTIONNALITÉS AVANCÉES (Existant)
# =======================================================================
@cocotb.test()
async def test_advanced_features(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await set_number(dut, 0, 32)
    await set_number(dut, 1, 50)

    assert await do_operation(dut, 'ADD', shift_button=1) == 5
    assert await do_operation(dut, 'AND', shift_button=1) == 50
    assert await do_operation(dut, 'OR', shift_button=1) == 8

# =======================================================================
# 3. TEST DE L'OVERFLOW ("E r r") (Existant)
# =======================================================================
@cocotb.test()
async def test_overflow_display(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    await set_number(dut, 0, 511)
    await set_number(dut, 1, 511)
    await do_operation(dut, 'ADD')
    await ClockCycles(dut.clk, 5)

    tube1_E = int(dut.user_project.bit_10NTreal.display.value) >> 7
    tube3_r = int(dut.user_project.bit_10NTreal.display.value) & 0x7F
    assert tube1_E == 0b0110000
    assert tube3_r == 0b1111010

# =======================================================================
# 4 à 15. SUITE DES TESTS INTÉGRÉE (12 Nouveaux cas)
# =======================================================================

@cocotb.test()
async def test_int_positive(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 100)
    await set_number(dut, 1, 250)
    assert await do_operation(dut, 'ADD') == 350

@cocotb.test()
async def test_int_zero(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 0)
    await set_number(dut, 1, 0)
    assert await do_operation(dut, 'ADD') == 0

@cocotb.test()
async def test_int_max_boundaries(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 511)
    await set_number(dut, 1, 0)
    assert await do_operation(dut, 'ADD') == 511

@cocotb.test()
async def test_bitwise_xor(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 0b101010101)
    await set_number(dut, 1, 0b010101010)
    assert await do_operation(dut, 'XOR') == 0b111111111

@cocotb.test()
async def test_shift_right_edge(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 255)
    assert await do_operation(dut, 'ADD', shift_button=1) == 15

@cocotb.test()
async def test_magnitude_cmp_b_greater(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 12)
    await set_number(dut, 1, 400)
    assert await do_operation(dut, 'AND', shift_button=1) == 400

@cocotb.test()
async def test_magnitude_cmp_a_greater(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 350)
    await set_number(dut, 1, 42)
    assert await do_operation(dut, 'AND', shift_button=1) == 350

@cocotb.test()
async def test_mirror_complex(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 0b100000001)
    assert await do_operation(dut, 'OR', shift_button=1) == 0b100000001

@cocotb.test()
async def test_int_large_values(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 450)
    await set_number(dut, 1, 450)
    assert await do_operation(dut, 'ADD') == 900

@cocotb.test()
async def test_float_simulation_1(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 15)
    await set_number(dut, 1, 20)
    assert await do_operation(dut, 'ADD') == 35

@cocotb.test()
async def test_float_simulation_2(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 111)
    await set_number(dut, 1, 222)
    assert await do_operation(dut, 'ADD') == 333

@cocotb.test()
async def test_float_simulation_max(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.rst_n.value = 1
    await set_number(dut, 0, 499)
    await set_number(dut, 1, 500)
    assert await do_operation(dut, 'ADD') == 999