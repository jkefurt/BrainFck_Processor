# BrainF*ck Processor (VHDL)

**Course:** Design of Computer Systems (INP)  
**University:** Brno University of Technology, Faculty of Information Technology (FIT VUT)  
**Language:** VHDL  
**Platform:** Questa Sim / GHDL / FPGA (PYNQ-Z2)

## 📖 About
This project involves the design and implementation of a custom **8-bit soft-core processor** in VHDL. The processor is designed to execute a program written in an extended version of the esoteric programming language **BrainF*ck**.

The goal was to implement a synthesizable processor architecture including a Control Unit (Finite State Machine) and a Datapath capable of handling memory operations, I/O, and nested loops.

## ⚙️ Architecture
The processor follows a modified Von Neumann architecture with shared memory for both program and data.

* **Memory:** 8KB circular buffer addressing (program + data).
* **Data Width:** 8-bit instructions and data.
* **Control Unit:** Implemented as a Finite State Machine (FSM) to decode instructions and control data flow.
* **Registers:**
    * `PC` (Program Counter): Points to the current instruction in memory.
    * `PTR` (Data Pointer): Points to the current data cell (circular buffer logic).
    * `CNT` (Counter): Used for handling nested loops logic (counting brackets `[` and `]`).

## 💻 Instruction Set
The processor supports the standard BrainF*ck commands plus specific extensions (like do-while loops and hex printing).

| Opcode | Char | Operation | Description |
| :--- | :---: | :--- | :--- |
| `0x3E` | `>` | `ptr++` | Increment data pointer (circular) |
| `0x3C` | `<` | `ptr--` | Decrement data pointer (circular) |
| `0x2B` | `+` | `*ptr++` | Increment value at current cell |
| `0x2D` | `-` | `*ptr--` | Decrement value at current cell |
| `0x5B` | `[` | `while(*ptr)` | Start of while loop (jump forward if zero) |
| `0x5D` | `]` | `}` | End of while loop (jump back if non-zero) |
| `0x28` | `(` | `do {` | Start of do-while loop |
| `0x29` | `)` | `} while(*ptr)` | End of do-while loop |
| `0x2E` | `.` | `putchar` | Print value as char |
| `0x2C` | `,` | `getchar` | Read char from input |
| `0x30-39` | `0-9` | `hex` | Print hex value (0-9) |
| `0x40` | `Q` | `return` | Halt execution |

## 🛠️ Project Structure
* `cpu.vhd`: The core VHDL implementation of the processor (Entity & Architecture).
* `login.b`: Sample BrainF*ck program that prints the user login.

## 🚀 Simulation & Testing
The project was validated using **Questa Sim** and automated tests provided within the course environment.

