    LIST
;==============================================================================
;   MIT License
;
;   Copyright (c) 2022 HAPCAN Home Automation Project (http://hapcan.com)
;
;   Permission is hereby granted, free of charge, to any person obtaining a copy
;   of this software and associated documentation files (the "Software"), to deal
;   in the Software without restriction, including without limitation the rights
;   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;   copies of the Software, and to permit persons to whom the Software is
;   furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in all
;   copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;   SOFTWARE.
;==============================================================================
;    Filename:              boot_3-4.asm
;    Date:                  March 2013
;    Author:                Jacek Siwilo
;    Description:           ASM file for UNIV 3 bootloader
;==============================================================================
;===  NODE SERIAL NUMBER  =====================================================
;==============================================================================
    #define     ID0     0x00            ;node serial number MSB
    #define     ID1     0x00            ;node serial number
    #define     ID2     0x0E            ;node serial number
    #define     ID3     0x78            ;node serial number LSB
;==============================================================================
;===  NEEDED FILES  ===========================================================
;==============================================================================
    LIST P=18F26K80                     ;directive to define processor
    #include <P18F26K80.INC>            ;processor specific variable definitions
    #include "boot_3-4.inc"             ;bootloader
    #include "boot_3-4_cfg.inc"         ;bootloader config file
;==============================================================================
    END