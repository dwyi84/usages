import SwiftUI
import AppKit

/// Brand marks for the provider cards.
///
/// The SVGs are embedded so the app stays self-contained (no network fetch and
/// no resource bundle to copy into the .app). `NSImage` renders SVG natively on
/// macOS 13+, and template rendering lets us tint each mark for light/dark mode.
public enum BrandIcon: String {
    case openCode
    case googleAI
    case openRouter
    case codex
    case claude
    case cursor
    case copilot
    case perplexity
    case deepseek
    
    var svg: String? {
        switch self {
        case .openCode:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22 24H2V0h20zM17 4.8H7v14.4h10z"/></svg>
            """
        case .googleAI:
            return """
            <svg width="180" height="180" viewBox="0 0 180 180" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M144.248 149.062C151.748 154.688 162.998 150.938 152.685 140.625C121.748 110.625 128.31 28.125 89.8727 28.125C51.4352 28.125 57.9977 110.625 27.0602 140.625C15.8102 151.875 27.9977 154.688 35.4977 149.062C64.5602 129.375 62.6852 94.6875 89.8727 94.6875C117.06 94.6875 115.185 129.375 144.248 149.062Z" fill="#3186FF"/>
            <mask id="mask0_6001_409" style="mask-type:alpha" maskUnits="userSpaceOnUse" x="22" y="28" width="136" height="125">
            <path d="M144.248 149.062C151.748 154.688 162.998 150.938 152.685 140.625C121.748 110.625 128.31 28.125 89.8727 28.125C51.4352 28.125 57.9977 110.625 27.0602 140.625C15.8102 151.875 27.9977 154.688 35.4977 149.062C64.5602 129.375 62.6852 94.6875 89.8727 94.6875C117.06 94.6875 115.185 129.375 144.248 149.062Z" fill="white"/>
            </mask>
            <g mask="url(#mask0_6001_409)">
            <g filter="url(#filter0_f_6001_409)"><ellipse cx="36.6225" cy="43.0872" rx="36.6225" ry="43.0872" transform="matrix(-0.112784 0.99362 -0.99362 -0.112781 106.557 -26.4847)" fill="#FFE432"/></g>
            <g filter="url(#filter1_f_6001_409)"><ellipse cx="155.163" cy="54.9292" rx="47.4118" ry="48.4541" transform="rotate(76.9243 155.163 54.9292)" fill="#FC413D"/></g>
            <g filter="url(#filter2_f_6001_409)"><ellipse cx="14.6006" cy="65.4425" rx="49.5515" ry="64.192" transform="rotate(74.1257 14.6006 65.4425)" fill="#00B95C"/></g>
            <g filter="url(#filter3_f_6001_409)"><ellipse cx="14.6006" cy="65.4425" rx="49.5515" ry="64.192" transform="rotate(74.1257 14.6006 65.4425)" fill="#00B95C"/></g>
            <g filter="url(#filter4_f_6001_409)"><ellipse cx="18.1226" cy="67.414" rx="48.5679" ry="53.4688" transform="rotate(45.6065 18.1226 67.414)" fill="#00B95C"/></g>
            <g filter="url(#filter5_f_6001_409)"><ellipse cx="121.837" cy="166.945" rx="46.6356" ry="44.9084" transform="rotate(76.9243 121.837 166.945)" fill="#3186FF"/></g>
            <g filter="url(#filter6_f_6001_409)"><ellipse cx="53.9456" cy="56.8997" rx="53.9456" ry="56.8997" transform="matrix(-0.409539 0.912293 -0.912294 -0.409537 162.811 -25.895)" fill="#FBBC04"/></g>
            <g filter="url(#filter7_f_6001_409)"><path d="M4.21557 239.063C-25.3231 227.467 25.1577 132.061 37.7105 100.085C50.2634 68.1097 84.3853 51.5888 113.924 63.1848C143.463 74.7809 178.474 138.65 165.921 170.626C153.368 202.601 33.7543 250.659 4.21557 239.063Z" fill="#3186FF"/></g>
            <g filter="url(#filter8_f_6001_409)"><path d="M183.197 120.315C175.289 129.545 154.652 124.839 137.102 109.803C119.553 94.7668 111.738 75.0955 119.646 65.8656C127.554 56.6357 148.191 61.3423 165.74 76.3782C183.289 91.414 191.105 111.085 183.197 120.315Z" fill="#749BFF"/></g>
            <g filter="url(#filter9_f_6001_409)"><ellipse cx="148.928" cy="36.7252" rx="71.1018" ry="44.199" transform="rotate(34.0763 148.928 36.7252)" fill="#FC413D"/></g>
            <g filter="url(#filter10_f_6001_409)"><ellipse cx="37.848" cy="46.0346" rx="38.1008" ry="22.1575" transform="rotate(112.516 37.848 46.0346)" fill="#FFEE48"/></g>
            </g>
            <defs>
            <filter id="filter0_f_6001_409" x="4.09591" y="-44.1761" width="111.037" height="98.4416" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="6.25234"/></filter>
            <filter id="filter1_f_6001_409" x="46.2974" y="-53.0009" width="217.731" height="215.86" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="30.2268"/></filter>
            <filter id="filter2_f_6001_409" x="-100.018" y="-36.7558" width="229.238" height="204.397" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="25.6957"/></filter>
            <filter id="filter3_f_6001_409" x="-100.018" y="-36.7558" width="229.238" height="204.397" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="25.6957"/></filter>
            <filter id="filter4_f_6001_409" x="-84.3985" y="-35.003" width="205.042" height="204.834" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="25.6957"/></filter>
            <filter id="filter5_f_6001_409" x="27.9915" y="71.5493" width="187.691" height="190.791" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="24.4184"/></filter>
            <filter id="filter6_f_6001_409" x="-11.8808" y="-98.7085" width="201.38" height="197.45" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="22.1301"/></filter>
            <filter id="filter7_f_6001_409" x="-44.4432" y="19.9522" width="252.513" height="260.404" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="19.7631"/></filter>
            <filter id="filter8_f_6001_409" x="81.1915" y="25.7722" width="140.46" height="134.637" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="17.6843"/></filter>
            <filter id="filter9_f_6001_409" x="55.1499" y="-47.2531" width="187.555" height="167.957" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="14.9365"/></filter>
            <filter id="filter10_f_6001_409" x="-24.2633" y="-27.1515" width="124.223" height="146.372" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="18.4865"/></filter>
            </defs>
            </svg>
            """
        case .openRouter:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M16.778 1.844v1.919q-.569-.026-1.138-.032-.708-.008-1.415.037c-1.93.126-4.023.728-6.149 2.237-2.911 2.066-2.731 1.95-4.14 2.75-.396.223-1.342.574-2.185.798-.841.225-1.753.333-1.751.333v4.229s.768.108 1.61.333c.842.224 1.789.575 2.185.799 1.41.798 1.228.683 4.14 2.75 2.126 1.509 4.22 2.11 6.148 2.236.88.058 1.716.041 2.555.005v1.918l7.222-4.168-7.222-4.17v2.176c-.86.038-1.611.065-2.278.021-1.364-.09-2.417-.357-3.979-1.465-2.244-1.593-2.866-2.027-3.68-2.508.889-.518 1.449-.906 3.822-2.59 1.56-1.109 2.614-1.377 3.978-1.466.667-.044 1.418-.017 2.278.02v2.176L24 6.014Z"/></svg>
            """
        case .claude:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"/></svg>
            """
        case .cursor:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M11.503.131 1.891 5.678a.84.84 0 0 0-.42.726v11.188c0 .3.162.575.42.724l9.609 5.55a1 1 0 0 0 .998 0l9.61-5.55a.84.84 0 0 0 .42-.724V6.404a.84.84 0 0 0-.42-.726L12.497.131a1.01 1.01 0 0 0-.996 0M2.657 6.338h18.55c.263 0 .43.287.297.515L12.23 22.918c-.062.107-.229.064-.229-.06V12.335a.59.59 0 0 0-.295-.51l-9.11-5.257c-.109-.063-.064-.23.061-.23"/></svg>
            """
        case .copilot:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M23.922 16.997C23.061 18.492 18.063 22.02 12 22.02 5.937 22.02.939 18.492.078 16.997A.641.641 0 0 1 0 16.741v-2.869a.883.883 0 0 1 .053-.22c.372-.935 1.347-2.292 2.605-2.656.167-.429.414-1.055.644-1.517a10.098 10.098 0 0 1-.052-1.086c0-1.331.282-2.499 1.132-3.368.397-.406.89-.717 1.474-.952C7.255 2.937 9.248 1.98 11.978 1.98c2.731 0 4.767.957 6.166 2.093.584.235 1.077.546 1.474.952.85.869 1.132 2.037 1.132 3.368 0 .368-.014.733-.052 1.086.23.462.477 1.088.644 1.517 1.258.364 2.233 1.721 2.605 2.656a.841.841 0 0 1 .053.22v2.869a.641.641 0 0 1-.078.256Zm-11.75-5.992h-.344a4.359 4.359 0 0 1-.355.508c-.77.947-1.918 1.492-3.508 1.492-1.725 0-2.989-.359-3.782-1.259a2.137 2.137 0 0 1-.085-.104L4 11.746v6.585c1.435.779 4.514 2.179 8 2.179 3.486 0 6.565-1.4 8-2.179v-6.585l-.098-.104s-.033.045-.085.104c-.793.9-2.057 1.259-3.782 1.259-1.59 0-2.738-.545-3.508-1.492a4.359 4.359 0 0 1-.355-.508Zm2.328 3.25c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm-5 0c.549 0 1 .451 1 1v2c0 .549-.451 1-1 1-.549 0-1-.451-1-1v-2c0-.549.451-1 1-1Zm3.313-6.185c.136 1.057.403 1.913.878 2.497.442.544 1.134.938 2.344.938 1.573 0 2.292-.337 2.657-.751.384-.435.558-1.15.558-2.361 0-1.14-.243-1.847-.705-2.319-.477-.488-1.319-.862-2.824-1.025-1.487-.161-2.192.138-2.533.529-.269.307-.437.808-.438 1.578v.021c0 .265.021.562.063.893Zm-1.626 0c.042-.331.063-.628.063-.894v-.02c-.001-.77-.169-1.271-.438-1.578-.341-.391-1.046-.69-2.533-.529-1.505.163-2.347.537-2.824 1.025-.462.472-.705 1.179-.705 2.319 0 1.211.175 1.926.558 2.361.365.414 1.084.751 2.657.751 1.21 0 1.902-.394 2.344-.938.475-.584.742-1.44.878-2.497Z"/></svg>
            """
        case .perplexity:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22.3977 7.0896h-2.3106V.0676l-7.5094 6.3542V.1577h-1.1554v6.1966L4.4904 0v7.0896H1.6023v10.3976h2.8882V24l6.932-6.3591v6.2005h1.1554v-6.0469l6.9318 6.1807v-6.4879h2.8882V7.0896zm-3.4657-4.531v4.531h-5.355l5.355-4.531zm-13.2862.0676 4.8691 4.4634H5.6458V2.6262zM2.7576 16.332V8.245h7.8476l-6.1149 6.1147v1.9723H2.7576zm2.8882 5.0404v-3.8852h.0001v-2.6488l5.7763-5.7764v7.0111l-5.7764 5.2993zm12.7086.0248-5.7766-5.1509V9.0618l5.7766 5.7766v6.5588zm2.8882-5.0652h-1.733v-1.9723L13.3948 8.245h7.8478v8.087z"/></svg>
            """
        case .deepseek:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M23.748 4.651c-.254-.124-.364.113-.512.233-.051.04-.094.09-.137.137-.372.397-.806.657-1.373.626-.829-.046-1.537.214-2.163.848-.133-.782-.575-1.248-1.247-1.548-.352-.155-.708-.311-.955-.65-.172-.24-.219-.509-.305-.774-.055-.16-.11-.323-.293-.35-.2-.031-.278.136-.356.276-.313.572-.434 1.202-.422 1.84.027 1.436.633 2.58 1.838 3.393.137.094.172.187.129.323-.082.28-.18.553-.266.833-.055.179-.137.218-.328.14a5.5 5.5 0 0 1-1.737-1.179c-.857-.828-1.631-1.743-2.597-2.46a12 12 0 0 0-.689-.47c-.985-.957.13-1.743.387-1.836.27-.098.094-.433-.778-.428-.872.003-1.67.295-2.687.685a3 3 0 0 1-.465.136 9.6 9.6 0 0 0-2.883-.101c-1.885.21-3.39 1.1-4.497 2.622C.082 8.776-.231 10.854.152 13.02c.403 2.284 1.568 4.175 3.36 5.653 1.857 1.533 3.997 2.284 6.438 2.14 1.482-.085 3.132-.284 4.994-1.86.47.234.962.328 1.78.398.629.058 1.235-.031 1.705-.129.735-.155.684-.836.418-.961-2.155-1.004-1.682-.595-2.112-.926 1.095-1.295 2.768-3.598 3.284-6.733.05-.346.115-.834.108-1.114-.004-.171.035-.238.23-.257a4.2 4.2 0 0 0 1.545-.475c1.397-.763 1.96-2.016 2.093-3.517.02-.23-.004-.467-.247-.588M11.58 18.168c-2.088-1.642-3.101-2.183-3.52-2.16-.39.024-.32.472-.234.763.09.288.207.487.371.74.114.167.192.416-.113.603-.673.416-1.842-.14-1.897-.168-1.361-.801-2.5-1.86-3.301-3.306-.775-1.393-1.225-2.888-1.299-4.482-.02-.385.094-.522.477-.592a4.7 4.7 0 0 1 1.53-.038c2.131.311 3.946 1.264 5.467 2.774.868.86 1.525 1.887 2.202 2.89.72 1.066 1.494 2.082 2.48 2.915.348.291.626.513.892.677-.802.09-2.14.109-3.055-.615zm1.001-6.44a.306.306 0 0 1 .415-.287.3.3 0 0 1 .113.074.3.3 0 0 1 .086.214c0 .17-.136.307-.308.307a.303.303 0 0 1-.306-.307m3.11 1.596c-.2.081-.4.151-.591.16a1.25 1.25 0 0 1-.798-.254c-.274-.23-.47-.358-.551-.758a1.7 1.7 0 0 1 .015-.588c.07-.327-.007-.537-.238-.727-.188-.156-.426-.199-.689-.199a.6.6 0 0 1-.254-.078.253.253 0 0 1-.114-.358 1 1 0 0 1 .192-.21c.356-.202.767-.136 1.146.016.352.144.618.408 1.001.782.392.451.462.576.685.915.176.264.336.536.446.848.066.194-.02.353-.25.45"/></svg>
            """
        case .codex:
            return """
            <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M19.503 0H4.496A4.496 4.496 0 000 4.496v15.007A4.496 4.496 0 004.496 24h15.007A4.496 4.496 0 0024 19.503V4.496A4.496 4.496 0 0019.503 0z" fill="#fff"></path><path d="M9.064 3.344a4.578 4.578 0 012.285-.312c1 .115 1.891.54 2.673 1.275.01.01.024.017.037.021a.09.09 0 00.043 0 4.55 4.55 0 013.046.275l.047.022.116.057a4.581 4.581 0 012.188 2.399c.209.51.313 1.041.315 1.595a4.24 4.24 0 01-.134 1.223.123.123 0 00.03.115c.594.607.988 1.33 1.183 2.17.289 1.425-.007 2.71-.887 3.854l-.136.166a4.548 4.548 0 01-2.201 1.388.123.123 0 00-.081.076c-.191.551-.383 1.023-.74 1.494-.9 1.187-2.222 1.846-3.711 1.838-1.187-.006-2.239-.44-3.157-1.302a.107.107 0 00-.105-.024c-.388.125-.78.143-1.204.138a4.441 4.441 0 01-1.945-.466 4.544 4.544 0 01-1.61-1.335c-.152-.202-.303-.392-.414-.617a5.81 5.81 0 01-.37-.961 4.582 4.582 0 01-.014-2.298.124.124 0 00.006-.056.085.085 0 00-.027-.048 4.467 4.467 0 01-1.034-1.651 3.896 3.896 0 01-.251-1.192 5.189 5.189 0 01.141-1.6c.337-1.112.982-1.985 1.933-2.618.212-.141.413-.251.601-.33.215-.089.43-.164.646-.227a.098.098 0 00.065-.066 4.51 4.51 0 01.829-1.615 4.535 4.535 0 011.837-1.388zm3.482 10.565a.637.637 0 000 1.272h3.636a.637.637 0 100-1.272h-3.636zM8.462 9.23a.637.637 0 00-1.106.631l1.272 2.224-1.266 2.136a.636.636 0 101.095.649l1.454-2.455a.636.636 0 00.005-.64L8.462 9.23z" fill="url(#lobe-icons-codex-_R_0_)"></path><defs><linearGradient gradientUnits="userSpaceOnUse" id="lobe-icons-codex-_R_0_" x1="12" x2="12" y1="3" y2="21"><stop stop-color="#B1A7FF"></stop><stop offset=".5" stop-color="#7A9DFF"></stop><stop offset="1" stop-color="#3941FF"></stop></linearGradient></defs></svg>
            """
        }
    }
    
    /// Antigravity and Codex are rendered in their original multi-color form.
    var isMulticolor: Bool {
        switch self {
        case .googleAI, .codex: return true
        default: return false
        }
    }
    
    /// Official 64×64 Antigravity PNG from Google's press kit. The SVG variant
    /// relies on CoreSVG filter support and renders flatter than the real app
    /// icon, so the official PNG is preferred for pixel-accurate color.
    var pngBase64: String? {
        switch self {
        case .googleAI:
            return "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"
        default:
            return nil
        }
    }
    
    var tint: Color {
        switch self {
        case .googleAI: return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .perplexity: return Color(red: 0.12, green: 0.72, blue: 0.80)
        case .deepseek: return Color(red: 0.34, green: 0.53, blue: 1.0)
        case .openRouter: return Color(red: 0.39, green: 0.45, blue: 0.55)
        case .codex: return Color(red: 0.06, green: 0.64, blue: 0.50)
        case .openCode, .cursor, .copilot: return .primary
        }
    }
    
    var fallbackSymbol: String {
        switch self {
        case .codex: return "cloud.fill"
        case .claude: return "asterisk"
        case .googleAI: return "sparkles"
        default: return "circle.fill"
        }
    }
    
    var accessibilityName: String {
        switch self {
        case .openCode: return "OpenCode"
        case .googleAI: return "Google Antigravity"
        case .openRouter: return "OpenRouter"
        case .codex: return "OpenAI Codex"
        case .claude: return "Claude"
        case .cursor: return "Cursor"
        case .copilot: return "GitHub Copilot"
        case .perplexity: return "Perplexity"
        case .deepseek: return "DeepSeek"
        }
    }
}

private final class BrandImageCache {
    static let shared = BrandImageCache()
    private var cache: [String: NSImage] = [:]
    
    func image(for brand: BrandIcon) -> NSImage? {
        if let cached = cache[brand.rawValue] { return cached }
        if let base64 = brand.pngBase64,
           let data = Data(base64Encoded: base64),
           let image = NSImage(data: data) {
            image.isTemplate = false
            cache[brand.rawValue] = image
            return image
        }
        guard let svg = brand.svg,
              let data = svg.data(using: .utf8),
              let image = NSImage(data: data) else {
            return nil
        }
        image.isTemplate = !brand.isMulticolor
        cache[brand.rawValue] = image
        return image
    }
}

public struct BrandIconView: View {
    let brand: BrandIcon
    var size: CGFloat = 14
    
    public init(_ brand: BrandIcon, size: CGFloat = 14) {
        self.brand = brand
        self.size = size
    }
    
    public var body: some View {
        Group {
            if let image = BrandImageCache.shared.image(for: brand) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(brand.isMulticolor ? .original : .template)
                    .interpolation(.high)
                    .foregroundStyle(brand.tint)
            } else {
                Image(systemName: brand.fallbackSymbol)
                    .font(.system(size: size * 0.92, weight: .semibold))
                    .foregroundStyle(brand.tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(brand.accessibilityName)
    }
}
