(function () {
    const courseRooms = [
        { name: '공학리더반', room: '글로벌라운지' },
        { name: '오토테크니션기초A반', room: '1학년 1반 교실' },
        { name: '오토테크니션기초B반', room: '1학년 2반 교실' },
        { name: '오토테크니션기초C반', room: '1학년 3반 교실' },
        { name: '오토테크니션심화반', room: '미래자동차 1관' },
        { name: '바디페인팅기초A반', room: '3학년 3반 교실' },
        { name: '바디페인팅기초B반', room: '3학년 4반 교실' },
        { name: '바디페인팅심화반', room: '미래자동차 2관' },
        { name: '바디리페어심화반', room: '미래자동차 3관' },
        { name: '컴퓨터활용기초반', room: '1-7 / 응용프로그래밍1실' },
        { name: '프로그래밍심화반', room: '데이터베이스실' },
        { name: '웹프로그래밍기초반', room: '전기실습실' },
        { name: '웹프로그래밍심화반', room: '응용프로그래밍2실' },
        { name: '그래픽디자인반', room: '제품디자인실' },
        { name: '1-8컴활', room: '1-8 / 응용프로그래밍3실' },
        { name: '전기기능심화반', room: '창의반(전기실습실)' }
    ];

    const operatingDates = [
        '2026-06-01',
        '2026-06-02',
        '2026-06-04',
        '2026-06-05',
        '2026-06-08',
        '2026-06-09',
        '2026-06-10',
        '2026-06-11',
        '2026-06-12',
        '2026-06-15',
        '2026-06-16',
        '2026-06-17',
        '2026-06-18',
        '2026-06-19'
    ];

    const exceptions = {
        '2026-06-03': {
            title: '지방선거일',
            message: '지방선거일 · 오늘은 방과후 수업이 없습니다.'
        }
    };

    window.GHAS_AFTER_SCHOOL_SCHEDULES = [
        {
            id: '2026-4-after-school-employment',
            title: '2026 4차 방과후수업(취업역량강화)',
            scheduleTitle: '4차 방과후수업',
            startDate: '2026-06-01',
            endDate: '2026-06-19',
            dinnerTime: '17:00~17:50',
            classTime: '18:00~19:40',
            durationMinutes: 100,
            operatingDates,
            exceptions,
            courseRooms
        }
    ];
})();
