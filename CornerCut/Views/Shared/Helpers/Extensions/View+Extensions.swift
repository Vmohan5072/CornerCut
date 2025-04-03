import SwiftUI

extension View {
    // Apply a card style to a view
    func cardStyle(backgroundColor: Color = Color(.systemBackground)) -> some View {
        self
            .padding()
            .background(backgroundColor)
            .cornerRadius(AppConstants.cornerRadius)
            .shadow(radius: 2)
            .padding(.horizontal)
    }
    
    // Add a section header to a view
    func withSectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            self
        }
    }
    
    // Conditionally apply a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // Hide view conditionally
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
    
    // Apply system-wide horizontal padding
    func standardHorizontalPadding() -> some View {
        self.padding(.horizontal, AppConstants.standardPadding)
    }
    
    // Apply a loading overlay
    func loadingOverlay(isLoading: Bool) -> some View {
        ZStack {
            self
                .disabled(isLoading)
                
            if isLoading {
                ZStack {
                    Color(.systemBackground)
                        .opacity(0.6)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    // Add a placeholder when content is empty
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            self
            
            if shouldShow {
                placeholder()
            }
        }
    }
    
    // Add a badge to a view
    func badge(text: String, color: Color = .red) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            
            Text(text)
                .font(.caption2)
                .padding(4)
                .background(color)
                .clipShape(Circle())
                .foregroundColor(.white)
                .offset(x: 8, y: -8)
        }
    }
    
    // Create a responsive layout that adjusts based on horizontal size class
    func responsiveHorizontalLayout<Content: View>(
        @ViewBuilder content: @escaping (Bool) -> Content
    ) -> some View {
        GeometryReader { geometry in
            content(geometry.size.width > 500)
        }
    }
    
    // Apply conditional frame width based on device size
    func adaptiveWidth(compact: CGFloat, regular: CGFloat) -> some View {
        GeometryReader { geometry in
            self.frame(width: geometry.size.width > 500 ? regular : compact)
        }
    }
}
