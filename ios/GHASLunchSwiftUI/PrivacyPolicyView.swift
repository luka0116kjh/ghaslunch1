import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppHeader(
                    title: "개인정보처리방침",
                    subtitle: "시행일: 2026년 4월 30일",
                    actionIcon: "chevron.left",
                    actionLabel: "앱으로 돌아가기",
                    action: { dismiss() }
                )

                InfoCard {
                    Text("GHAS 오늘의 급식은 경기자동차과학고등학교 학생의 급식 및 시간표 확인을 돕기 위해 제작된 비공식 정보 제공 앱입니다. 본 앱은 학교 또는 교육청의 공식 앱이 아닙니다.")
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(5)
                        .foregroundStyle(AppTheme.text(scheme).opacity(0.9))
                        .padding(.bottom, 22)

                    PolicySection(title: "수집하는 정보") {
                        PolicyBullet("방문자 수 집계를 위한 익명 방문 카운트")
                        PolicyBullet("사용자가 알림을 허용한 경우 Firebase Cloud Messaging 토큰을 해시 처리한 식별자, 갱신 시각, 플랫폼 정보")
                        PolicyBullet("앱 설정을 유지하기 위한 로컬 저장소 정보: 테마, 알림 설정 등")
                    }

                    PolicySection(title: "정보 이용 목적") {
                        PolicyBullet("급식 및 시간표 정보 제공")
                        PolicyBullet("사용자가 요청한 알림 기능 제공")
                        PolicyBullet("서비스 이용량 확인 및 안정성 개선")
                    }

                    PolicySection(title: "제3자 서비스") {
                        PolicyText("이 앱은 NEIS 오픈 API와 Firebase Hosting, Firebase Realtime Database, Firebase Cloud Messaging을 사용합니다. 각 서비스 제공 과정에서 Google/Firebase의 정책이 적용될 수 있습니다.")
                    }

                    PolicySection(title: "데이터 출처 및 고지") {
                        PolicyText("본 서비스는 NEIS 교육정보 개방포털의 Open API를 활용하여 급식 및 시간표 정보를 제공합니다. 제공되는 급식 및 시간표 정보는 학교 또는 교육청 사정에 따라 실제와 다를 수 있습니다.")
                        Link("NEIS 교육정보 개방포털", destination: URL(string: "https://open.neis.go.kr")!)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(AppTheme.text(scheme))
                            .underline(true, color: AppTheme.primary)
                            .padding(.top, 10)
                    }

                    PolicySection(title: "보관 및 삭제") {
                        PolicyText("알림을 해제하면 앱은 저장된 알림 토큰 식별자 삭제를 시도합니다. 앱 데이터를 삭제하면 로컬 설정도 함께 삭제됩니다.")
                    }

                    PolicySection(title: "권한") {
                        PolicyText("앱은 알림 권한만 요청하며, 카메라, 마이크, 위치, 결제 권한을 요청하지 않습니다.")
                    }

                    PolicySection(title: "문의", isLast: true) {
                        HStack(spacing: 4) {
                            PolicyText("문의와 개선 요청은")
                            Link("GitHub", destination: URL(string: "https://github.com/luka0116kjh")!)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(AppTheme.text(scheme))
                                .underline(true, color: AppTheme.primary)
                            PolicyText("를 통해 전달할 수 있습니다.")
                        }
                    }
                }
                .padding(.bottom, 16)

                PrimaryButton(title: "앱으로 돌아가기", systemImage: "chevron.left") {
                    dismiss()
                }

                privacyFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 30)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background(scheme).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var privacyFooter: some View {
        VStack(spacing: 8) {
            Text("이 앱은 학교 공식 앱이 아닌 학생 제작 정보 제공 앱입니다.")
                .font(.system(size: 10))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.subText(scheme).opacity(0.75))
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Text("GHAS 오늘의 급식")
                Link("GITHUB: luka", destination: URL(string: "https://github.com/luka0116kjh")!)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.subText(scheme).opacity(0.5))
            .textCase(.uppercase)
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
    }
}

private struct PolicySection<Content: View>: View {
    let title: String
    var isLast = false
    @ViewBuilder let content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != "수집하는 정보" {
                Divider()
                    .background(AppTheme.border(scheme))
                    .padding(.bottom, 10)
            }

            SectionTitle(title: title)
            content
        }
        .padding(.bottom, isLast ? 0 : 20)
    }
}

private struct PolicyText: View {
    let text: String

    @Environment(\.colorScheme) private var scheme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .lineSpacing(5)
            .foregroundStyle(AppTheme.subText(scheme))
    }
}

private struct PolicyBullet: View {
    let text: String

    @Environment(\.colorScheme) private var scheme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.subText(scheme))

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(AppTheme.subText(scheme))
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
