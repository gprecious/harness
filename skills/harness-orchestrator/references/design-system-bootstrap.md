# Design System Bootstrap Reference

> 참조 디자인(Figma/시안)이 없을 때, 프로젝트에 맞는 디자인 시스템을 처음부터 구축하는 가이드.
> Refactoring UI, Atomic Design, Anthropic Frontend Aesthetics 연구 기반.

## 1. Design Brief 작성 (PLAN 단계에서)

코드를 한 줄도 쓰기 전에 4가지를 정의:

1. **Purpose** — 누가 왜 사용하는가?
2. **Tone** — 극단적 미학 방향 하나 선택 (NOT "모던하고 깔끔한")
   - 예: "에디토리얼 매거진", "브루탈리스트 테크", "따뜻한 수공예", "인더스트리얼 다크"
3. **Constraints** — 프레임워크, 성능 예산, 접근성 요구사항
4. **Differentiator** — 이 인터페이스를 기억에 남게 만드는 한 가지

## 2. Design Tokens 정의

### Color Palette
- HSL로 정의 (hex보다 추론이 쉬움)
- **8-10 greys** (순수 black #000 대신 매우 어두운 grey 사용)
- **5-10 shades per color** (9단계가 이상적)
- **Dominant + Sharp Accent** — 균등 분배가 아님
- 배경에 미세한 saturation 추가 (따뜻한 grey)
- Semantic naming: `--color-primary-500`, `--color-surface`, `--color-text-secondary`

### Typography
- **금지 폰트:** Inter, Roboto, Open Sans, Lato, Arial, Space Grotesk
- **2 families max:** Display(제목) + Body(본문)으로 대비
  - 고대비 조합: serif + geometric sans, display + monospace
  - Weight 극단: 100/200 vs 800/900 (400 vs 600의 밋밋한 중간 피하기)
- **Modular scale:** 12, 14, 16(base), 20, 24, 30, 36+ px
- **Size jump:** heading과 body 사이 3x+ 차이 (1.5x는 부족)
- Line height: heading 1.1-1.25, body 1.5-1.75
- Max line width: 45-75 characters (20-35em)

### Spacing (8pt Grid)
- Base: 4, 8, 16, 24, 32, 48, 64 px
- **Internal <= External:** padding <= margin (Gestalt 근접성)
- "Too much whitespace" → "just right" (항상 생각보다 더 필요함)

### Border Radius
- 3-4단계: 4px (subtle), 8px (default), 16px (rounded), 9999px (pill)
- 모든 요소에 동일 radius 적용 금지

### Shadows (5 Elevation Levels)
- Level 1: subtle card separation
- Level 2: dropdown/tooltip
- Level 3: modal overlay
- Level 4: floating action
- Level 5: dialog
- 두 레이어: diffuse(ambient) + small dark(direct light), vertical offset

### Motion
- Fast: 150ms, Normal: 250ms, Slow: 350ms
- **하나의 orchestrated moment** > 산발적 micro-interactions
- Page load stagger (animation-delay) > scattered hover effects

## 3. Tailwind v4 @theme 적용

```css
@theme {
  /* Colors — Dominant + Accent */
  --color-primary-50: oklch(0.97 0.01 250);
  --color-primary-500: oklch(0.55 0.15 250);
  --color-primary-900: oklch(0.25 0.08 250);
  --color-accent: oklch(0.65 0.20 30);
  --color-surface: oklch(0.98 0.005 80);
  --color-text: oklch(0.15 0.01 250);
  --color-text-secondary: oklch(0.45 0.01 250);

  /* Typography — High Contrast Pairing */
  --font-display: "Clash Display", sans-serif;
  --font-body: "Satoshi", sans-serif;

  /* Spacing — 8pt Grid */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  --spacing-2xl: 3rem;
  --spacing-3xl: 4rem;

  /* Radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 1rem;
  --radius-pill: 9999px;
}
```

## 4. Atomic Design 구조

```
atoms/       → Button, Input, Label, Icon, Badge, Avatar
molecules/   → SearchBar, FormField, NavLink, Card
organisms/   → Header, Sidebar, ProductGrid, CommentSection
templates/   → DashboardLayout, AuthLayout, BlogLayout
pages/       → /dashboard, /login, /posts/[id]
```

atoms부터 시작하여 위로 조합. atoms가 design tokens를 직접 참조.

## 5. Anti-Slop Checklist

코드 작성 후, 제출 전 반드시 확인:

- [ ] 금지 폰트 없음 (Inter, Roboto, Arial, system defaults)
- [ ] 보라색 그라데이션 + 흰색 배경 없음
- [ ] 레이아웃에 비대칭 또는 예상 밖 구성 있음
- [ ] Color palette에 명확한 dominant + accent 관계
- [ ] Typography에 고대비 pairing (다른 family, 극단적 weight)
- [ ] Motion이 orchestrated (핵심 한 순간, 산발적 아님)
- [ ] 배경에 분위기 있음 (순수 흰/회색이 아닌)
- [ ] 디자인이 프로젝트 맥락에 특화 (다른 앱과 교체 불가)
- [ ] 간격이 정의된 scale 값만 사용 (magic number 없음)
- [ ] 모든 색상이 token palette에서 가져옴 (inline hex 없음)

## 6. 권장 Skills / Plugins

| Tool | Purpose | Install |
|------|---------|---------|
| **frontend-design** | Aesthetic direction before coding, anti-slop guidelines | 기본 설치됨 |
| **Impeccable** | Enhanced anti-slop, 7 reference files, 20 steering commands | `npx skills add pbakaus/impeccable` |
| **UI/UX Pro Max** | 161 palettes, 57 font pairings, Design System Generator | `npx skills add nextlevelbuilder/ui-ux-pro-max-skill` |
| **theme-factory** | 10개 pre-set theme + custom theme | `claude plugin install theme-factory@anthropic-agent-skills` |

## Sources

- Adam Wathan & Steve Schoger, "Refactoring UI"
- Brad Frost, "Atomic Design" — atomicdesign.bradfrost.com
- W3C Design Tokens Community Group, "Design Tokens Format Module 2025.10"
- Anthropic, "Prompting for Frontend Aesthetics" — claude.com/cookbook
- Anthropic, "Improving Frontend Design Through Skills" — claude.com/blog
- Tailwind CSS v4.0, "@theme directive" — tailwindcss.com/docs/theme
