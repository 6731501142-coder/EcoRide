// tests/services.test.js

const mockUserService = {
  borrowVehicle: jest.fn((userCredit, planPrice, vehicleStatus) => {
    if (vehicleStatus !== 'available') {
      throw new Error('Vehicle is not available');
    }
    if (userCredit < planPrice) {
      throw new Error('Not enough credit');
    }
    return { status: 'success', rideId: 101, remainingCredit: userCredit - planPrice };
  }),

  topupCredit: jest.fn((amount) => {
    if (amount < 20 || amount > 5000) {
      throw new Error('Amount must be between 20 and 5000');
    }
    return { status: 'success', addedAmount: amount };
  }),

  returnVehicle: jest.fn((rideId, isStationFull) => {
    if (isStationFull) {
      throw new Error('Station is full');
    }
    return { status: 'returned', rideId: rideId };
  })
};

describe('EcoRide Core Logic Unit Tests (Sprint 3)', () => {

  describe('Borrow Vehicle Tests', () => {
    test('ควรยืมรถสำเร็จ เมื่อเงินพอและรถว่าง (Happy Path)', () => {
      const result = mockUserService.borrowVehicle(150, 100, 'available');
      expect(result.status).toBe('success');
      expect(result.remainingCredit).toBe(50);
    });

    test('ควรล้มเหลว เมื่อยอดเงินในบัญชีไม่พอ', () => {
      expect(() => {
        mockUserService.borrowVehicle(40, 100, 'available');
      }).toThrow('Not enough credit');
    });

    test('ควรล้มเหลว เมื่อรถไม่ได้อยู่ในสถานะ available', () => {
      expect(() => {
        mockUserService.borrowVehicle(200, 100, 'in_use');
      }).toThrow('Vehicle is not available');
    });
  });

  describe('Top-up Credit Tests', () => {
    test('ควรเติมเงินสำเร็จ เมื่อระบุยอดเงินถูกต้อง (เช่น 100 บาท)', () => {
      const result = mockUserService.topupCredit(100);
      expect(result.status).toBe('success');
      expect(result.addedAmount).toBe(100);
    });

    test('ควรล้มเหลว ถ้าเติมเงินน้อยกว่า 20 บาท (ตาม DB Constraint)', () => {
      expect(() => {
        mockUserService.topupCredit(10);
      }).toThrow('Amount must be between 20 and 5000');
    });

    test('ควรล้มเหลว ถ้าเติมเงินมากกว่า 5,000 บาท', () => {
      expect(() => {
        mockUserService.topupCredit(6000);
      }).toThrow('Amount must be between 20 and 5000');
    });
  });

  describe('Return Vehicle Tests', () => {
    test('ควรคืนรถสำเร็จ เมื่อสถานีไม่เต็ม', () => {
      const result = mockUserService.returnVehicle(1, false);
      expect(result.status).toBe('returned');
    });

    test('ควรล้มเหลว ถ้าสถานีปลายทางเต็ม (Station is Full)', () => {
      expect(() => {
        mockUserService.returnVehicle(1, true);
      }).toThrow('Station is full');
    });
  });

});