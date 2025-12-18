// Post-Development Plugin Types

// ============================================
// Post-Development Master Plan
// ============================================

export interface PostDevelopmentPlan {
  project: ProjectInfo;
  tasks: TaskMap;
  config: PostDevConfig;
  progress: Progress;
  createdAt: string;
  updatedAt: string;
}

export interface ProjectInfo {
  name: string;
  description: string;
  type: 'saas' | 'ecommerce' | 'blog' | 'portfolio' | 'service' | 'other';
  techStack: string[];
  baseUrl: string;
  routes: string[];
  analyzedAt: string;
}

export interface TaskMap {
  seo: TaskStatus;
  screenshots: TaskStatus;
  personas: TaskStatus;
  ads: TaskStatus;
  articles: TaskStatus;
  landing: TaskStatus;
}

export interface TaskStatus {
  status: 'pending' | 'in_progress' | 'done' | 'error' | 'skipped';
  dependsOn: string[];
  startedAt?: string;
  completedAt?: string;
  error?: string;
  output?: string;
}

export interface PostDevConfig {
  baseUrl: string;
  outputDir: string;
  targetMarkets: ('b2b' | 'b2c' | 'b2g' | 'b2d')[];
}

export interface Progress {
  completedTasks: number;
  totalTasks: number;
  startedAt: string | null;
  completedAt: string | null;
}

// ============================================
// SEO Types
// ============================================

export interface SEOPlan {
  project: {
    name: string;
    domain: string;
    type: string;
    industry: string;
  };
  global: {
    brandKeywords: string[];
    targetAudience: string[];
    competitors: string[];
    tone: string;
  };
  pages: SEOPageEntry[];
  assets: {
    favicon: { status: string };
    ogImages: { status: string };
  };
  generatedAt: string | null;
  lastUpdated: string | null;
}

export interface SEOPageEntry {
  route: string;
  priority: number;
  status: 'pending' | 'analyzed' | 'generated' | 'exported';
  file: string;
}

export interface SEOPageData {
  route: string;
  priority: number;
  changefreq: 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never';
  title: {
    text: string;
    length: number;
    guidelines: string;
  };
  description: {
    text: string;
    length: number;
    guidelines: string;
  };
  keywords: {
    primary: string;
    secondary: string[];
    longtail: string[];
  };
  headings: {
    h1: string;
    h2s: string[];
  };
  openGraph: OpenGraphData;
  twitter: TwitterCardData;
  structuredData: object;
  suggestions: {
    contentGaps: string[];
    imageNeeds: ImageNeed[];
  };
}

export interface OpenGraphData {
  title: string;
  description: string;
  type: string;
  image: {
    recommended: string;
    dimensions: string;
    alt: string;
  };
  url: string;
}

export interface TwitterCardData {
  card: 'summary' | 'summary_large_image' | 'app' | 'player';
  title: string;
  description: string;
  image: string;
}

export interface ImageNeed {
  type: string;
  description: string;
  source?: string;
}

// ============================================
// Screenshot Types
// ============================================

export interface ScreenshotPlan {
  config: ScreenshotConfig;
  viewports: Record<string, ViewportConfig>;
  colorModes: Record<string, ColorModeConfig>;
  screenshots: ScreenshotEntry[];
}

export interface ScreenshotConfig {
  baseUrl: string;
  outputDir: string;
  format: 'png' | 'jpeg' | 'webp';
  quality: number;
  waitTimeout: number;
  animationWait: number;
}

export interface ViewportConfig {
  width: number;
  height: number;
  deviceScaleFactor?: number;
  isMobile?: boolean;
  hasTouch?: boolean;
}

export interface ColorModeConfig {
  type: 'class' | 'attribute' | 'media' | 'toggle';
  setup: {
    add?: string[];
    remove?: string[];
    attribute?: { name: string; value: string };
    selector?: string;
  };
}

export interface ScreenshotEntry {
  id: string;
  name: string;
  route: string;
  viewports: string[];
  modes: string[];
  fullPage: boolean;
  actions?: ScreenshotAction[];
  focus?: FocusArea[];
  auth?: AuthConfig;
  status: 'pending' | 'in_progress' | 'done' | 'error' | 'skipped';
  lastRun?: string;
  files?: string[];
  error?: string;
  duration?: number;
}

export interface ScreenshotAction {
  type: 'wait' | 'waitFor' | 'click' | 'fill' | 'select' | 'hover' | 'scroll' | 'scrollTo' | 'press' | 'evaluate';
  selector?: string;
  value?: string;
  ms?: number;
  x?: number;
  y?: number;
  key?: string;
  script?: string;
}

export interface FocusArea {
  selector: string;
  name: string;
  padding?: number;
}

export interface AuthConfig {
  type: 'form' | 'cookie' | 'header' | 'oauth';
  loginUrl?: string;
  credentials?: {
    email: string;
    password: string;
  };
  cookie?: {
    name: string;
    value: string;
  };
  header?: {
    name: string;
    value: string;
  };
  successIndicator?: string;
}

// ============================================
// Persona Types
// ============================================

export interface PersonasPlan {
  personas: PersonaEntry[];
  createdAt: string;
  updatedAt: string;
}

export interface PersonaEntry {
  id: string;
  name: string;
  type: 'primary' | 'secondary' | 'edge';
  market: 'b2b' | 'b2c' | 'b2g' | 'b2d';
  file: string;
  status: 'pending' | 'created' | 'strategized';
}

export interface Persona {
  id: string;
  name: string;
  type: 'primary' | 'secondary' | 'edge';
  market: 'b2b' | 'b2c' | 'b2g' | 'b2d';
  demographics: Demographics;
  psychographics: Psychographics;
  behavior: Behavior;
  journey: BuyerJourney;
  messaging: Messaging;
}

export interface Demographics {
  age: string;
  gender: string;
  location: string;
  income: string;
  education: string;
  jobTitle: string;
  companySize?: string;
  industry?: string;
}

export interface Psychographics {
  values: string[];
  goals: string[];
  challenges: string[];
  fears: string[];
  motivations: string[];
}

export interface Behavior {
  decisionMaking: string;
  researchStyle: string;
  preferredChannels: string[];
  contentPreferences: string[];
  buyingTriggers: string[];
  objections: string[];
}

export interface BuyerJourney {
  awareness: JourneyStage;
  consideration: JourneyStage;
  decision: JourneyStage;
  retention?: JourneyStage;
}

export interface JourneyStage {
  touchpoints: string[];
  questions: string[];
  emotions?: string[];
}

export interface Messaging {
  hook: string;
  valueProposition: string;
  proofPoints: string[];
  tone: string;
}

export interface Strategy {
  persona: string;
  market: string;
  positioning: Positioning;
  messagingFramework: MessagingFramework;
  channels: Channels;
  contentPillars: ContentPillar[];
  conversionFunnel: ConversionFunnel;
}

export interface Positioning {
  category: string;
  differentiation: string;
  competitiveAdvantage: string;
  tagline: string;
}

export interface MessagingFramework {
  primary: {
    headline: string;
    subheadline: string;
    supportingPoints: string[];
  };
  emotional: {
    headline: string;
    angle: string;
  };
  logical: {
    headline: string;
    angle: string;
  };
}

export interface Channels {
  primary: ChannelRecommendation[];
  secondary: ChannelRecommendation[];
}

export interface ChannelRecommendation {
  channel: string;
  rationale: string;
  content?: string;
  format?: string;
  keywords?: string[];
}

export interface ContentPillar {
  pillar: string;
  topics: string[];
  formats: string[];
}

export interface ConversionFunnel {
  tofu: FunnelStage;
  mofu: FunnelStage;
  bofu: FunnelStage;
}

export interface FunnelStage {
  goal: string;
  content: string[];
  cta: string;
  metrics?: string[];
}

// ============================================
// Ad Types
// ============================================

export interface AdsPlan {
  ads: AdEntry[];
  createdAt: string;
  updatedAt: string;
}

export interface AdEntry {
  id: string;
  platform: 'instagram' | 'facebook' | 'linkedin' | 'twitter' | 'google';
  format: string;
  persona: string;
  file: string;
  status: 'draft' | 'ready' | 'exported';
}

export interface Ad {
  id: string;
  platform: string;
  format: string;
  persona: string;
  objective: 'awareness' | 'consideration' | 'conversion';
  creative: AdCreative;
  copy: AdCopy;
  variations: AdVariation[];
  targeting: AdTargeting;
  status: 'draft' | 'ready' | 'exported';
  createdAt: string;
}

export interface AdCreative {
  type: 'single-image' | 'carousel' | 'video' | 'stories';
  dimensions: {
    width: number;
    height: number;
    aspectRatio: string;
  };
  image?: {
    source: string;
    treatment?: string;
    overlay?: AdOverlay;
  };
  images?: Array<{
    source: string;
    headline?: string;
  }>;
}

export interface AdOverlay {
  headline?: {
    text: string;
    position: string;
    style: object;
  };
  cta?: {
    text: string;
    position: string;
    style: object;
  };
  logo?: {
    position: string;
    size: string;
  };
}

export interface AdCopy {
  primary: string;
  cta: string;
  ctaUrl: string;
  headline?: string;
  description?: string;
  hashtags?: string[];
}

export interface AdVariation {
  id: string;
  change: string;
  [key: string]: any;
}

export interface AdTargeting {
  interests?: string[];
  demographics?: object;
  behaviors?: string[];
  lookalike?: {
    source: string;
    percentage: string;
  };
}

// ============================================
// Article Types
// ============================================

export interface ArticlesPlan {
  articles: ArticleEntry[];
  createdAt: string;
  updatedAt: string;
}

export interface ArticleEntry {
  id: string;
  type: 'problem-solution' | 'feature-deepdive' | 'case-study';
  title: string;
  file: string;
  status: 'outline' | 'draft' | 'ready' | 'published';
}

export interface Article {
  id: string;
  title: string;
  subtitle: string;
  slug: string;
  metadata: ArticleMetadata;
  seo: ArticleSEO;
  structure: ArticleSection[];
  images: ArticleImage[];
  cta: {
    primary: { text: string; url: string };
    secondary?: { text: string; url: string };
  };
  status: string;
  createdAt: string;
}

export interface ArticleMetadata {
  type: string;
  targetPersona: string;
  buyerStage: string;
  estimatedReadTime: string;
  wordCount: number;
}

export interface ArticleSEO {
  metaTitle: string;
  metaDescription: string;
  primaryKeyword: string;
  secondaryKeywords: string[];
  targetWordCount: number;
}

export interface ArticleSection {
  section: string;
  heading: string | null;
  purpose: string;
  wordCount: number;
  content?: string;
  image?: {
    description?: string;
    source?: string;
    alt: string;
    caption?: string;
  };
  callout?: {
    type: string;
    content: string;
  };
  cta?: object;
}

export interface ArticleImage {
  placement: string;
  source: string;
  treatment?: string;
  alt: string;
  width?: string;
  caption?: string;
}

// ============================================
// Landing Page Types
// ============================================

export interface LandingPagesPlan {
  pages: LandingPageEntry[];
  createdAt: string;
  updatedAt: string;
}

export interface LandingPageEntry {
  id: string;
  persona: string;
  url: string;
  file: string;
  status: 'draft' | 'ready' | 'exported';
}

export interface LandingPage {
  id: string;
  persona: string;
  url: string;
  template: string;
  meta: LandingPageMeta;
  design: LandingPageDesign;
  sections: LandingPageSection[];
  tracking: LandingPageTracking;
  status: string;
  createdAt: string;
}

export interface LandingPageMeta {
  title: string;
  description: string;
  ogImage: string;
}

export interface LandingPageDesign {
  colorScheme: 'light' | 'dark';
  primaryColor: string;
  style: string;
  layout: string;
}

export interface LandingPageSection {
  id: string;
  type: string;
  order: number;
  content: object;
  image?: object;
}

export interface LandingPageTracking {
  utm: {
    source: string;
    medium: string;
    campaign: string;
  };
  events: Array<{
    name: string;
    trigger: string;
    selector?: string;
  }>;
}
