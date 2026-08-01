//
//  GroupSetupView.swift
//  FitIn
//
//  Created by Clarissa Kristanto on 7/28/26.
//
import SwiftUI

// Lets the user create a new group (and see the shareable code to hand
// out) or join an existing group by pasting a code.
struct GroupSetupView: View {
    @EnvironmentObject var groupSetupViewModel: GroupSetupViewModel

    @State private var groupName: String = ""
    @State private var mode: Mode = .create

    enum Mode: String, CaseIterable {
        case create = "Create"
        case join = "Join"
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Set Up Your Group")
                .font(.title2.bold())
                .padding(.top, 32)

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            switch mode {
            case .create:
                createSection
            case .join:
                joinSection
            }

            if let errorMessage = groupSetupViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding(.bottom, 32)
    }

    private var createSection: some View {
        VStack(spacing: 16) {
            TextField("Group name", text: $groupName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await groupSetupViewModel.createGroup(name: groupName)
                }
            } label: {
                if groupSetupViewModel.isBusy {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Create Group").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(groupSetupViewModel.isBusy || groupName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var joinSection: some View {
        VStack(spacing: 16) {
            TextField("Paste group link or code", text: $groupSetupViewModel.joinCodeInput)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await groupSetupViewModel.joinGroup()
                }
            } label: {
                if groupSetupViewModel.isBusy {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Join Group").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(groupSetupViewModel.isBusy)
        }
    }

}

#Preview {
    GroupSetupView()
        .environmentObject(GroupSetupViewModel())
}
