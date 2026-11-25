import React, { useState } from "react";
import {
  Image,
  ImageSourcePropType,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Svg, {
  Circle,
  Defs,
  LinearGradient as SvgLinearGradient,
  RadialGradient as SvgRadialGradient,
  Stop,
} from "react-native-svg";

import { FIGMA_IMAGES, FigmaSvg } from "@/components/figma-assets";
import { GradientWave } from "@/components/lit-brand";
import { useAppAuth, UserSession } from "@/lib/auth-state";

export type MainTab = "home" | "discover" | "events" | "profile";
export type SubScreen =
  | null
  | "create-post"
  | "edit-profile"
  | "vibing"
  | "event-details"
  | "select-ticket"
  | "order-summary"
  | "ticket-details"
  | "settings";

export interface FeedPost {
  id: string;
  author: {
    name: string;
    username: string;
    avatar: ImageSourcePropType;
  };
  timeAgo: string;
  content: string;
  image: ImageSourcePropType;
  hasPagination?: boolean;
  likes: string;
  isLiked?: boolean;
  comments: number;
  shares: number;
  linkedEvent?: {
    label: string;
    title: string;
    thumb: ImageSourcePropType;
  };
}

interface WelcomeScreenProps {
  session: UserSession | null;
}

const INITIAL_POSTS: FeedPost[] = [
  {
    id: "post_1",
    author: {
      name: "Maya Chen",
      username: "maya_vibes",
      avatar: FIGMA_IMAGES.avatar_maya,
    },
    timeAgo: "2h ago",
    content:
      "Last night at Neon Nights was amazing! The vibe was electric. Can't wait for the next event!",
    image: FIGMA_IMAGES.post_1,
    hasPagination: true,
    likes: "1.2k",
    isLiked: true,
    comments: 87,
    shares: 87,
    linkedEvent: {
      label: "Linked Event",
      title: "Neon Nights: The Underground",
      thumb: FIGMA_IMAGES.event_thumb,
    },
  },
  {
    id: "post_2",
    author: {
      name: "Maya Chen",
      username: "maya_vibes",
      avatar: FIGMA_IMAGES.avatar_maya,
    },
    timeAgo: "2h ago",
    content:
      "Last night at Neon Nights was amazing! The vibe was electric. Can't wait for the next event!",
    image: FIGMA_IMAGES.post_2,
    hasPagination: false,
    likes: "1.2k",
    isLiked: true,
    comments: 87,
    shares: 87,
    linkedEvent: {
      label: "Linked Event",
      title: "Neon Nights: The Underground",
      thumb: FIGMA_IMAGES.event_thumb,
    },
  },
];

const FLAME_STORIES = [
  { id: "story_1", name: "athik.design", avatar: FIGMA_IMAGES.story_athik },
  { id: "story_2", name: "ui_ux frog", avatar: FIGMA_IMAGES.story_frog },
  { id: "story_3", name: "dev_ninja", avatar: FIGMA_IMAGES.story_ninja },
  { id: "story_4", name: "dev_artisan", avatar: FIGMA_IMAGES.story_artisan },
];

const TRENDING_TAGS = [
  "#RooftopVibes",
  "#NeonNights",
  "#LuminousJourney",
  "#ElectricDreams",
  "#UrbanVibes",
  "#StarlitEscape",
  "#MidnightGlow",
  "#CosmicBeats",
  "#RadiantReverie",
];

const DISCOVER_USERS = [
  {
    id: "u1",
    name: "Emma Wilson",
    meta: "@emma_wilson · 9.3k vibers",
    avatar: FIGMA_IMAGES.user_emma,
    vibing: false,
  },
  {
    id: "u2",
    name: "Olivia Brown",
    meta: "@olivia_b · 11.4k vibers",
    avatar: FIGMA_IMAGES.user_olivia,
    vibing: true,
  },
  {
    id: "u3",
    name: "Ava Martinez",
    meta: "@ava_martinez · 15.2k vibers",
    avatar: FIGMA_IMAGES.user_ava,
    vibing: false,
  },
  {
    id: "u4",
    name: "Ethan Rodriguez",
    meta: "@ethan_r · 13.6k vibers",
    avatar: FIGMA_IMAGES.user_ethan,
    vibing: true,
  },
  {
    id: "u5",
    name: "Isabella Lee",
    meta: "@isabella_lee · 6.9k vibers",
    avatar: FIGMA_IMAGES.user_isabella,
    vibing: false,
  },
];

const VIBING_LIST_USERS = [
  { id: "v1", name: "Emma Wilson", meta: "@emma_wilson · 9.3k vibers", avatar: FIGMA_IMAGES.user_emma },
  { id: "v2", name: "Noah Smith", meta: "@noah_smith23 · 8.1k vibers", avatar: FIGMA_IMAGES.user_noah },
  { id: "v3", name: "Olivia Brown", meta: "@olivia_b · 11.4k vibers", avatar: FIGMA_IMAGES.user_olivia },
  { id: "v4", name: "Ava Martinez", meta: "@ava_martinez · 15.2k vibers", avatar: FIGMA_IMAGES.user_ava },
  { id: "v5", name: "Lucas Davis", meta: "@lucas_d · 10.5k vibers", avatar: FIGMA_IMAGES.user_lucas },
  { id: "v6", name: "Mia Garcia", meta: "@mia_garcia · 7.8k vibers", avatar: FIGMA_IMAGES.user_mia },
  { id: "v7", name: "Ethan Rodriguez", meta: "@ethan_r · 13.6k vibers", avatar: FIGMA_IMAGES.user_ethan },
  { id: "v8", name: "Isabella Lee", meta: "@isabella_lee · 6.9k vibers", avatar: FIGMA_IMAGES.user_isabella },
  { id: "v9", name: "James Wilson", meta: "@james_wilson · 12.1k vibers", avatar: FIGMA_IMAGES.user_james },
  { id: "v10", name: "Sophia Clark", meta: "@sophia_c · 14.3k vibers", avatar: FIGMA_IMAGES.user_sophia },
];

const TRENDING_EVENTS = [
  {
    id: "e1",
    venue: "Warehouse 12",
    title: "Sunset Groove: A Summer Festival",
    meta: "$60 · 2026-07-15",
  },
  {
    id: "e2",
    venue: "Warehouse 7",
    title: "Eclipse of Beats: The Midnight Show",
    meta: "$50 · 2026-05-10",
  },
  {
    id: "e3",
    venue: "Warehouse 34",
    title: "Rhythm and Rave: Electric Vibes",
    meta: "$55 · 2026-08-05",
  },
  {
    id: "e4",
    venue: "Warehouse 45",
    title: "Bass Drop: The Epic Night",
    meta: "$70 · 2026-09-01",
  },
  {
    id: "e5",
    venue: "Warehouse 19",
    title: "Chill Wave: A Relaxed Evening",
    meta: "$40 · 2026-10-12",
  },
];

const GALLERY_ROWS = [
  [FIGMA_IMAGES.gallery_1, FIGMA_IMAGES.gallery_2, FIGMA_IMAGES.gallery_3],
  [FIGMA_IMAGES.gallery_4, FIGMA_IMAGES.gallery_5, FIGMA_IMAGES.gallery_6],
  [FIGMA_IMAGES.gallery_7, FIGMA_IMAGES.gallery_8, FIGMA_IMAGES.gallery_9],
];

export function WelcomeScreen({ session }: WelcomeScreenProps) {
  const insets = useSafeAreaInsets();
  const { signOut } = useAppAuth();

  const [activeTab, setActiveTab] = useState<MainTab>("home");
  const [subScreen, setSubScreen] = useState<SubScreen>(null);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);

  // Feed & Discover interactive state
  const [posts, setPosts] = useState<FeedPost[]>(INITIAL_POSTS);
  const [discoverSearch, setDiscoverSearch] = useState("");
  const [eventsSearch, setEventsSearch] = useState("");
  const [vibingMap, setVibingMap] = useState<Record<string, boolean>>({
    u2: true,
    u4: true,
    v1: true,
    v2: true,
    v3: true,
    v4: true,
    v5: true,
    v6: true,
    v7: true,
    v8: true,
    v9: true,
    v10: true,
  });

  // Profile & Edit Profile state
  const [profileTab, setProfileTab] = useState<"posts" | "events">("posts");
  const [vibingTab, setVibingTab] = useState<"vibing" | "viber">("vibing");
  const [editFullName, setEditFullName] = useState(
    session?.profile?.display_name || session?.user?.name || "Jayden Ross",
  );
  const [editUsername, setEditUsername] = useState(
    session?.profile?.username ? `@${session.profile.username}` : "@jayden_lit",
  );
  const [editBio, setEditBio] = useState(
    session?.profile?.bio || "Tell the world your vibe...",
  );
  const [editSocialLink, setEditSocialLink] = useState(
    session?.profile?.website || "https://yoursite.com",
  );
  const [editLocation, setEditLocation] = useState(
    session?.profile?.location || "New York, NY",
  );

  // Create Post state
  const [newPostCaption, setNewPostCaption] = useState("");
  const [newPostHasMedia, setNewPostHasMedia] = useState(false);

  // Ticket selection quantities
  const [qtyGeneral, setQtyGeneral] = useState(1);
  const [qtyVip, setQtyVip] = useState(1);
  const [qtyVvip, setQtyVvip] = useState(1);

  // Settings toggles
  const [pushEnabled, setPushEnabled] = useState(true);
  const [emailEnabled, setEmailEnabled] = useState(false);
  const [privateAccount, setPrivateAccount] = useState(true);
  const [activityStatus, setActivityStatus] = useState(false);

  const ticketSubtotal = qtyGeneral * 60 + qtyVip * 120 + qtyVvip * 200;
  const ticketTotal = ticketSubtotal + 20;

  const toggleVibe = (id: string) => {
    setVibingMap((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const handlePublishPost = () => {
    const caption =
      newPostCaption.trim() ||
      "Last night at Neon Nights was amazing! The vibe was electric. Can't wait for the next event!";
    const created: FeedPost = {
      id: `post_${Date.now()}`,
      author: {
        name: editFullName || "Maya Chen",
        username: editUsername.replace(/^@/, "") || "maya_vibes",
        avatar: FIGMA_IMAGES.avatar_maya,
      },
      timeAgo: "Just now",
      content: caption,
      image: FIGMA_IMAGES.post_1,
      hasPagination: true,
      likes: "1",
      isLiked: true,
      comments: 0,
      shares: 0,
      linkedEvent: {
        label: "Linked Event",
        title: "Neon Nights: The Underground",
        thumb: FIGMA_IMAGES.event_thumb,
      },
    };
    setPosts((prev) => [created, ...prev]);
    setNewPostCaption("");
    setNewPostHasMedia(false);
    setSubScreen(null);
    setActiveTab("home");
  };

  const topPad = Math.max(insets.top, 14);

  /* ═══════════════════════════════════════════════════════════════════════════
   * SUB-SCREENS (Create Post, Edit Profile, Vibing, Event Details, Tickets, Settings)
   * ═══════════════════════════════════════════════════════════════════════════ */

  if (subScreen === "create-post") {
    return (
      <View style={styles.root}>
        <GradientWave height={275} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen(null)}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Create Post</Text>
        </View>

        <ScrollView
          contentContainerStyle={styles.createPostBody}
          showsVerticalScrollIndicator={false}
        >
          {/* People / Location / Events tag buttons (607:12060) */}
          <View style={styles.createPostTagRow}>
            <Pressable style={styles.createPostTagBtn}>
              <FigmaSvg name="post_tag_people" />
              <Text style={styles.createPostTagText}>People</Text>
            </Pressable>
            <Pressable style={styles.createPostTagBtn}>
              <FigmaSvg name="icon_pin_small" />
              <Text style={styles.createPostTagText}>Location</Text>
            </Pressable>
            <Pressable style={styles.createPostTagBtn}>
              <FigmaSvg name="nav_events_inactive" width={12} height={12} />
              <Text style={styles.createPostTagText}>Events</Text>
            </Pressable>
          </View>

          <TextInput
            style={styles.createPostInput}
            value={newPostCaption}
            onChangeText={setNewPostCaption}
            placeholder="What’s on your mind?"
            placeholderTextColor="#F2F2F8"
            multiline
          />

          {/* 335x504 Media Dropzone (607:12083) */}
          <Pressable
            style={styles.mediaUploadBox}
            onPress={() => setNewPostHasMedia((v) => !v)}
          >
            {newPostHasMedia ? (
              <Image
                source={FIGMA_IMAGES.post_1}
                style={styles.mediaUploadPreview}
                resizeMode="cover"
              />
            ) : (
              <View style={styles.mediaUploadInner}>
                <FigmaSvg name="post_media_upload" />
                <Text style={styles.mediaUploadLabel}>
                  Tap to add photos or videos
                </Text>
              </View>
            )}
          </Pressable>

          <Pressable style={styles.primaryFullBtn} onPress={handlePublishPost}>
            <Text style={styles.primaryFullBtnText}>Post</Text>
          </Pressable>
        </ScrollView>
      </View>
    );
  }

  if (subScreen === "edit-profile") {
    return (
      <View style={styles.root}>
        <GradientWave height={260} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen(null)}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Edit Profile</Text>
        </View>

        <ScrollView
          contentContainerStyle={styles.editProfileScroll}
          showsVerticalScrollIndicator={false}
        >
          {/* 124x124 Avatar with ring and camera badge (283:1645) */}
          <View style={styles.editAvatarWrap}>
            <FigmaSvg name="profile_ring" width={124} height={124} />
            <Image
              source={FIGMA_IMAGES.profile_athik}
              style={styles.editAvatarImg}
            />
            <View style={styles.editCameraBadge}>
              <FigmaSvg name="icon_camera" />
            </View>
          </View>

          <View style={styles.editFormStack}>
            <View style={styles.editFieldGroup}>
              <Text style={styles.editFieldLabel}>Full Name</Text>
              <View style={styles.editPillInputWrap}>
                <TextInput
                  style={styles.editPillInput}
                  value={editFullName}
                  onChangeText={setEditFullName}
                  placeholder="Full Name"
                  placeholderTextColor="rgba(255,255,255,0.4)"
                />
              </View>
            </View>

            <View style={styles.editFieldGroup}>
              <Text style={styles.editFieldLabel}>User Name</Text>
              <View style={styles.editPillInputWrap}>
                <TextInput
                  style={styles.editPillInput}
                  value={editUsername}
                  onChangeText={setEditUsername}
                  placeholder="@username"
                  placeholderTextColor="rgba(255,255,255,0.4)"
                  autoCapitalize="none"
                />
              </View>
            </View>

            <View style={styles.editFieldGroup}>
              <Text style={styles.editFieldLabel}>Bio</Text>
              <View style={styles.editBioInputWrap}>
                <TextInput
                  style={styles.editBioInput}
                  value={editBio}
                  onChangeText={setEditBio}
                  placeholder="Tell the world your vibe..."
                  placeholderTextColor="rgba(255,255,255,0.6)"
                  multiline
                />
              </View>
            </View>

            <View style={styles.editFieldGroup}>
              <Text style={styles.editFieldLabel}>Social Link</Text>
              <View style={styles.editSocialInputWrap}>
                <TextInput
                  style={[styles.editPillInput, { paddingRight: 64 }]}
                  value={editSocialLink}
                  onChangeText={setEditSocialLink}
                  placeholder="https://yoursite.com"
                  placeholderTextColor="rgba(255,255,255,0.4)"
                  autoCapitalize="none"
                />
                <Pressable style={styles.editSocialAddBtn}>
                  <Text style={styles.editSocialAddText}>Add</Text>
                </Pressable>
              </View>
              <View style={styles.editSocialChipRow}>
                <FigmaSvg name="icon_facebook" />
                <Text style={styles.editSocialChipText}>@athik_foisal</Text>
              </View>
            </View>

            <View style={styles.editFieldGroup}>
              <Text style={styles.editFieldLabel}>Location</Text>
              <View style={styles.editPillInputWrap}>
                <TextInput
                  style={styles.editPillInput}
                  value={editLocation}
                  onChangeText={setEditLocation}
                  placeholder="New York, NY"
                  placeholderTextColor="rgba(255,255,255,0.4)"
                />
              </View>
            </View>
          </View>

          <Pressable
            style={[styles.primaryFullBtn, { marginTop: 28 }]}
            onPress={() => setSubScreen(null)}
          >
            <Text style={styles.primaryFullBtnText}>Save Changes</Text>
          </Pressable>
        </ScrollView>
      </View>
    );
  }

  if (subScreen === "vibing") {
    return (
      <View style={styles.root}>
        <GradientWave height={260} />
        <View style={[styles.vibingHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen(null)}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.vibingHeaderTitle}>@athik_uiux</Text>
          <Pressable style={styles.vibingAddUserBtn}>
            <FigmaSvg name="icon_user_plus" />
          </Pressable>
        </View>

        {/* Vibing / Viber Tabs (283:1689) */}
        <View style={styles.twoTabRow}>
          <Pressable
            style={[
              styles.twoTabItem,
              vibingTab === "vibing"
                ? styles.twoTabItemActive
                : styles.twoTabItemInactive,
            ]}
            onPress={() => setVibingTab("vibing")}
          >
            <Text
              style={
                vibingTab === "vibing"
                  ? styles.twoTabTextActive
                  : styles.twoTabTextInactive
              }
            >
              Vibing
            </Text>
          </Pressable>
          <Pressable
            style={[
              styles.twoTabItem,
              vibingTab === "viber"
                ? styles.twoTabItemActive
                : styles.twoTabItemInactive,
            ]}
            onPress={() => setVibingTab("viber")}
          >
            <Text
              style={
                vibingTab === "viber"
                  ? styles.twoTabTextActive
                  : styles.twoTabTextInactive
              }
            >
              Viber
            </Text>
          </Pressable>
        </View>

        <ScrollView
          contentContainerStyle={styles.vibingListScroll}
          showsVerticalScrollIndicator={false}
        >
          {VIBING_LIST_USERS.map((u) => {
            const isVibing = vibingMap[u.id] ?? true;
            return (
              <View key={u.id} style={styles.userListRow}>
                <Image source={u.avatar} style={styles.userListAvatar} />
                <View style={styles.userListInfo}>
                  <Text style={styles.userListName}>{u.name}</Text>
                  <Text style={styles.userListMeta}>{u.meta}</Text>
                </View>
                <Pressable
                  style={[
                    styles.vibeActionPill,
                    isVibing ? styles.vibeActionPillActive : styles.vibeActionPillIdle,
                  ]}
                  onPress={() => toggleVibe(u.id)}
                >
                  <Text
                    style={
                      isVibing
                        ? styles.vibeActionTextActive
                        : styles.vibeActionTextIdle
                    }
                  >
                    {isVibing ? "Vibing" : "Vibe"}
                  </Text>
                </Pressable>
              </View>
            );
          })}
        </ScrollView>
      </View>
    );
  }

  if (subScreen === "event-details") {
    return (
      <View style={styles.root}>
        <ScrollView
          contentContainerStyle={{ paddingBottom: 110 }}
          showsVerticalScrollIndicator={false}
        >
          {/* 220px Hero Banner (283:2209) */}
          <View style={styles.eventDetailsHero}>
            <Image
              source={FIGMA_IMAGES.event_hero}
              style={styles.eventDetailsHeroImg}
              resizeMode="cover"
            />
            <View style={styles.eventDetailsHeroOverlay} />
            <View style={[styles.eventDetailsTopBar, { top: topPad }]}>
              <Pressable
                style={styles.darkGlassIconBtn}
                onPress={() => setSubScreen(null)}
                hitSlop={10}
              >
                <FigmaSvg name="icon_back_chevron" />
              </Pressable>
              <Text style={styles.subHeaderTitle}>Event Details</Text>
              <Pressable style={styles.darkGlassIconBtn}>
                <View style={{ transform: [{ rotate: "90deg" }] }}>
                  <FigmaSvg name="icon_more_dots" />
                </View>
              </Pressable>
            </View>
          </View>

          <View style={styles.eventDetailsBody}>
            {/* Title + Rating + Going (283:2243) */}
            <View style={{ gap: 8, width: "100%" }}>
              <Text style={styles.eventDetailsTitle}>
                Sunset Groove: A Summer Festival
              </Text>
              <View style={styles.eventDetailsMetaRow}>
                <View style={styles.ratingRow}>
                  <View style={styles.ratingBadge}>
                    <FigmaSvg name="icon_star_gold" />
                    <Text style={styles.ratingBadgeText}>4.8</Text>
                  </View>
                  <Text style={styles.ratingCountText}>127 ratings</Text>
                </View>
                <View style={styles.goingRow}>
                  <Text style={styles.goingCountMuted}>342 going</Text>
                  <View style={styles.attendeeStack}>
                    <Image
                      source={FIGMA_IMAGES.attendee_1}
                      style={[styles.attendeeAvatar, { marginLeft: 0 }]}
                    />
                    <Image
                      source={FIGMA_IMAGES.attendee_2}
                      style={styles.attendeeAvatar}
                    />
                    <Image
                      source={FIGMA_IMAGES.attendee_3}
                      style={styles.attendeeAvatar}
                    />
                  </View>
                </View>
              </View>
            </View>

            {/* Date / Venue / Attendees Info Card (283:2262) */}
            <View style={styles.eventInfoCard}>
              <View style={styles.eventInfoItem}>
                <View style={styles.eventInfoIconCircle}>
                  <FigmaSvg name="nav_events_inactive" width={16} height={16} />
                </View>
                <View style={styles.eventInfoTextCol}>
                  <Text style={styles.eventInfoLabel}>Date & Time</Text>
                  <Text style={styles.eventInfoValue}>
                    Sunday, June 21, 2026 · 10:00 PM
                  </Text>
                </View>
              </View>
              <View style={styles.cardDivider} />
              <View style={styles.eventInfoItem}>
                <View style={styles.eventInfoIconCircle}>
                  <FigmaSvg name="icon_pin_small" width={16} height={16} />
                </View>
                <View style={styles.eventInfoTextCol}>
                  <Text style={styles.eventInfoLabel}>Venue</Text>
                  <Text style={styles.eventInfoValue}>
                    Warehouse 23 · Brooklyn, NY
                  </Text>
                </View>
              </View>
              <View style={styles.cardDivider} />
              <View style={styles.eventInfoItem}>
                <View style={styles.eventInfoIconCircle}>
                  <FigmaSvg name="icon_attendees" />
                </View>
                <View style={[styles.eventInfoTextCol, { flex: 1 }]}>
                  <Text style={styles.eventInfoLabel}>Attendees</Text>
                  <Text style={styles.eventInfoValue}>342 / 500</Text>
                  <View style={styles.progressTrack}>
                    <View style={styles.progressFill} />
                  </View>
                </View>
              </View>
            </View>

            {/* About (283:2300) */}
            <View style={{ gap: 12, width: "100%" }}>
              <Text style={styles.sectionHeading}>About</Text>
              <View style={{ gap: 4 }}>
                <Text style={styles.aboutParagraph}>
                  {`The most anticipated underground electronic music event of the year. Three floors of music, immersive visuals, and the city's best DJs. Limited tickets available.`}
                </Text>
                <Text style={styles.showMoreSmall}>Show More</Text>
              </View>
            </View>

            {/* Event Schedule & Highlights Card (283:2305) */}
            <View style={styles.scheduleCard}>
              <View style={styles.scheduleCol}>
                <Text style={styles.sectionHeading}>Event Schedule</Text>
                <View style={{ gap: 4 }}>
                  {[
                    ["7:00 PM", "Door Open"],
                    ["7:30 PM", "Opening Act"],
                    ["8:30 PM", "Main Perform"],
                    ["9:30 PM", "DJ Session"],
                    ["11:00 PM", "Event Close"],
                  ].map(([time, label]) => (
                    <View key={time} style={styles.scheduleRow}>
                      <Text style={styles.scheduleTime}>{time}</Text>
                      <Text style={styles.scheduleLabel}>{label}</Text>
                    </View>
                  ))}
                </View>
              </View>
              <View style={styles.scheduleVerticalDivider} />
              <View style={styles.scheduleCol}>
                <Text style={styles.sectionHeading}>Event Highlights</Text>
                <View style={{ gap: 4 }}>
                  {[
                    "Live Performances",
                    "Food & Drinks",
                    "Parking Available",
                    "18+ Event",
                  ].map((item) => (
                    <Text key={item} style={styles.scheduleLabel}>
                      {item}
                    </Text>
                  ))}
                </View>
              </View>
            </View>

            {/* Location Map Card (283:2333) */}
            <View style={{ gap: 12, width: "100%" }}>
              <Text style={styles.sectionHeading}>Location</Text>
              <View style={styles.locationCard}>
                <View style={styles.locationMapWrap}>
                  <Image
                    source={FIGMA_IMAGES.event_map}
                    style={styles.locationMapImg}
                    resizeMode="cover"
                  />
                  <View style={styles.locationPinOverlay}>
                    <FigmaSvg name="icon_map_marker" />
                  </View>
                </View>
                <View style={styles.locationFooterRow}>
                  <View style={{ flex: 1, gap: 3 }}>
                    <Text style={styles.locationVenueSmall}>Warehouse 23</Text>
                    <Text style={styles.locationCityText}>Brooklyn, NY</Text>
                  </View>
                  <Pressable style={styles.smallOrangePillBtn}>
                    <Text style={styles.smallOrangePillText}>Get Directions</Text>
                  </Pressable>
                </View>
              </View>
            </View>

            {/* Hosted By (283:2345) */}
            <View style={{ gap: 12, width: "100%" }}>
              <Text style={styles.sectionHeading}>Hosted By</Text>
              <View style={styles.hostCard}>
                <Image
                  source={FIGMA_IMAGES.user_emma}
                  style={styles.userListAvatar}
                />
                <View style={{ flex: 1, gap: 4 }}>
                  <Text style={styles.userListName}>Emma Wilson</Text>
                  <Text style={styles.userListMeta}>
                    Creating unforgettable experiences
                  </Text>
                </View>
                <Pressable
                  style={[styles.vibeActionPill, styles.vibeActionPillIdle]}
                >
                  <Text style={styles.vibeActionTextIdle}>Vibe</Text>
                </Pressable>
              </View>
            </View>

            {/* From This Event (283:2354) */}
            <View style={{ gap: 12, width: "100%" }}>
              <Text style={styles.sectionHeading}>From This Event</Text>
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={{ gap: 8 }}
              >
                {[
                  FIGMA_IMAGES.from_event_1,
                  FIGMA_IMAGES.from_event_2,
                  FIGMA_IMAGES.from_event_3,
                  FIGMA_IMAGES.from_event_4,
                ].map((img, idx) => (
                  <Image
                    key={idx}
                    source={img}
                    style={styles.fromEventThumb}
                    resizeMode="cover"
                  />
                ))}
              </ScrollView>
            </View>
          </View>
        </ScrollView>

        {/* Bottom Purchase Bar (283:2365) */}
        <View style={styles.stickyBottomBar}>
          <View style={{ flex: 1 }}>
            <Text style={styles.priceBigText}>$60</Text>
            <Text style={styles.priceSubLabel}>Tickets from</Text>
          </View>
          <Pressable
            style={[styles.primaryFullBtn, { flex: 1 }]}
            onPress={() => setSubScreen("select-ticket")}
          >
            <Text style={styles.primaryFullBtnText}>Purchas & RSVP</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  if (subScreen === "select-ticket") {
    return (
      <View style={styles.root}>
        <GradientWave height={260} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen("event-details")}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Select Ticket</Text>
        </View>

        <View style={styles.ticketContentWrap}>
          {/* Event Mini Summary Header (283:2407) */}
          <View style={styles.ticketEventSummary}>
            <Image
              source={FIGMA_IMAGES.event_thumb}
              style={styles.ticketEventThumb}
            />
            <View style={{ flex: 1, gap: 8 }}>
              <View style={{ gap: 4 }}>
                <Text style={styles.ticketEventTitle}>Summer music fast</Text>
                <View style={styles.eventMetaInlineRow}>
                  <View style={styles.eventMetaItem}>
                    <FigmaSvg name="icon_pin_small" />
                    <Text style={styles.eventMetaText}>Warehouse 23</Text>
                  </View>
                  <View style={styles.eventMetaItem}>
                    <FigmaSvg name="icon_clock_small" />
                    <Text style={styles.eventMetaText}>10 Jul, 10:00 PM</Text>
                  </View>
                </View>
              </View>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                <Text style={styles.eventMetaText}>Tickets from</Text>
                <Text style={styles.ticketTierPrice}>$60</Text>
              </View>
            </View>
          </View>

          {/* 3 Ticket Tiers (283:2426) */}
          <View style={{ gap: 12, width: "100%" }}>
            {[
              {
                label: "General Admission",
                price: "$60",
                qty: qtyGeneral,
                setQty: setQtyGeneral,
              },
              {
                label: "VIP Pass",
                price: "$120",
                qty: qtyVip,
                setQty: setQtyVip,
              },
              {
                label: "VVIP Table (4 Pax)",
                price: "$200",
                qty: qtyVvip,
                setQty: setQtyVvip,
              },
            ].map((tier) => (
              <View key={tier.label} style={styles.ticketTierCard}>
                <View style={{ flex: 1, gap: 4 }}>
                  <Text style={styles.ticketTierName}>{tier.label}</Text>
                  <Text style={styles.ticketTierPrice}>{tier.price}</Text>
                </View>
                <View style={styles.qtyStepperRow}>
                  <Pressable
                    style={styles.roundIconBtn}
                    onPress={() => tier.setQty(Math.max(0, tier.qty - 1))}
                  >
                    <FigmaSvg name="icon_minus" />
                  </Pressable>
                  <Text style={styles.qtyValueText}>{tier.qty}</Text>
                  <Pressable
                    style={styles.roundIconBtn}
                    onPress={() => tier.setQty(tier.qty + 1)}
                  >
                    <FigmaSvg name="icon_plus" />
                  </Pressable>
                </View>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.stickyBottomColumnBar}>
          <View style={styles.totalRow}>
            <Text style={styles.priceSubLabel}>Total</Text>
            <Text style={styles.priceBigText}>${ticketSubtotal}</Text>
          </View>
          <Pressable
            style={styles.primaryFullBtn}
            onPress={() => setSubScreen("order-summary")}
          >
            <Text style={styles.primaryFullBtnText}>Continue</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  if (subScreen === "order-summary") {
    return (
      <View style={styles.root}>
        <GradientWave height={260} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen("select-ticket")}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Order Summary</Text>
        </View>

        <View style={styles.ticketContentWrap}>
          <View style={styles.ticketEventSummary}>
            <Image
              source={FIGMA_IMAGES.event_thumb}
              style={styles.ticketEventThumb}
            />
            <View style={{ flex: 1, gap: 8 }}>
              <View style={{ gap: 4 }}>
                <Text style={styles.ticketEventTitle}>Summer music fast</Text>
                <View style={styles.eventMetaInlineRow}>
                  <View style={styles.eventMetaItem}>
                    <FigmaSvg name="icon_pin_small" />
                    <Text style={styles.eventMetaText}>Warehouse 23</Text>
                  </View>
                  <View style={styles.eventMetaItem}>
                    <FigmaSvg name="icon_clock_small" />
                    <Text style={styles.eventMetaText}>10 Jul, 10:00 PM</Text>
                  </View>
                </View>
              </View>
              <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
                <Text style={styles.eventMetaText}>Tickets from</Text>
                <Text style={styles.ticketTierPrice}>$60</Text>
              </View>
            </View>
          </View>

          {/* Breakdown Card (283:2524) */}
          <View style={styles.orderBreakdownCard}>
            <View style={{ gap: 8, width: "100%" }}>
              <View style={styles.orderItemRow}>
                <View style={{ gap: 2 }}>
                  <Text style={styles.ticketTierName}>General Admission</Text>
                  <Text style={styles.eventMetaText}>Qty: {qtyGeneral}</Text>
                </View>
                <Text style={styles.orderPriceText}>${qtyGeneral * 60}</Text>
              </View>
              <View style={styles.orderItemRow}>
                <View style={{ gap: 2 }}>
                  <Text style={styles.ticketTierName}>VIP Pass</Text>
                  <Text style={styles.eventMetaText}>Qty: {qtyVip}</Text>
                </View>
                <Text style={styles.orderPriceText}>${qtyVip * 120}</Text>
              </View>
              <View style={styles.orderItemRow}>
                <View style={{ gap: 2 }}>
                  <Text style={styles.ticketTierName}>VVIP Table (4 Pax)</Text>
                  <Text style={styles.eventMetaText}>Qty: {qtyVvip}</Text>
                </View>
                <Text style={styles.orderPriceText}>${qtyVvip * 200}</Text>
              </View>
            </View>
            <View style={styles.cardDivider} />
            <View style={{ gap: 10, width: "100%" }}>
              <View style={styles.orderItemRow}>
                <Text style={styles.eventMetaText}>Subtotal</Text>
                <Text style={styles.ticketTierName}>${ticketSubtotal}</Text>
              </View>
              <View style={styles.orderItemRow}>
                <Text style={styles.eventMetaText}>Services Fee</Text>
                <Text style={styles.orderPriceText}>$20</Text>
              </View>
            </View>
            <View style={styles.cardDivider} />
            <View style={styles.orderItemRow}>
              <Text style={styles.ticketTierName}>Total</Text>
              <Text style={styles.ticketTierName}>${ticketTotal}</Text>
            </View>
          </View>

          {/* Payment Method (283:2554) */}
          <View style={{ gap: 12, width: "100%" }}>
            <Text style={styles.sectionHeading}>Select Payment Method</Text>
            <View style={styles.stripeCard}>
              <FigmaSvg name="icon_stripe" />
              <Text style={[styles.ticketTierName, { flex: 1 }]}>Strip</Text>
              <FigmaSvg name="icon_radio_selected" />
            </View>
          </View>

          <View style={styles.securePaymentRow}>
            <FigmaSvg name="icon_lock_small" />
            <Text style={styles.eventMetaText}>Secure Payment</Text>
          </View>
        </View>

        <View style={styles.stickyBottomColumnBar}>
          <View style={styles.totalRow}>
            <Text style={styles.priceSubLabel}>Total</Text>
            <Text style={styles.priceBigText}>${ticketTotal}</Text>
          </View>
          <Pressable
            style={styles.primaryFullBtn}
            onPress={() => setSubScreen("ticket-details")}
          >
            <Text style={styles.primaryFullBtnText}>Confirm Payment</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  if (subScreen === "ticket-details") {
    return (
      <View style={styles.root}>
        <GradientWave height={260} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen(null)}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Ticket Details</Text>
        </View>

        <ScrollView
          contentContainerStyle={[styles.ticketContentWrap, { paddingBottom: 150 }]}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.ticketEventSummary}>
            <Image
              source={FIGMA_IMAGES.event_thumb}
              style={styles.ticketEventThumb}
            />
            <View style={{ flex: 1, gap: 4 }}>
              <Text style={styles.ticketEventTitle}>Summer music fast</Text>
              <View style={styles.eventMetaInlineRow}>
                <View style={styles.eventMetaItem}>
                  <FigmaSvg name="icon_pin_small" />
                  <Text style={styles.eventMetaText}>Warehouse 23</Text>
                </View>
                <View style={styles.eventMetaItem}>
                  <FigmaSvg name="icon_clock_small" />
                  <Text style={styles.eventMetaText}>10 Jul, 10:00 PM</Text>
                </View>
              </View>
              <Text style={styles.eventMetaText}>
                Porches Date: 10 Jul, 10:00 PM
              </Text>
            </View>
          </View>

          {/* Exact Figma QR Code (283:2676) */}
          <View style={styles.qrCodeContainer}>
            <FigmaSvg name="qr_code_matrix" width={335} height={335} />
            <View style={styles.qrCenterBadgeWrap}>
              <FigmaSvg name="qr_center_badge" />
            </View>
          </View>

          <View style={{ gap: 8, width: "100%" }}>
            <View style={styles.orderItemRow}>
              <Text style={styles.ticketTierName}>General Admission</Text>
              <Text style={styles.eventMetaText}>0{qtyGeneral}</Text>
            </View>
            <View style={styles.orderItemRow}>
              <Text style={styles.ticketTierName}>VIP Pass</Text>
              <Text style={styles.eventMetaText}>0{qtyVip}</Text>
            </View>
            <View style={styles.orderItemRow}>
              <Text style={styles.ticketTierName}>VVIP Table (4 Pax)</Text>
              <Text style={styles.eventMetaText}>0{qtyVvip}</Text>
            </View>
          </View>
        </ScrollView>

        <View style={styles.stickyBottomColumnBar}>
          <Pressable
            style={styles.primaryFullBtn}
            onPress={() => setSubScreen(null)}
          >
            <Text style={styles.primaryFullBtnText}>Download Ticket</Text>
          </Pressable>
          <Pressable
            style={styles.secondaryFullBtn}
            onPress={() => setSubScreen(null)}
          >
            <Text style={styles.secondaryFullBtnText}>Share Ticket</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  if (subScreen === "settings") {
    return (
      <View style={styles.root}>
        <GradientWave height={275} />
        <View style={[styles.subHeaderRow, { marginTop: topPad }]}>
          <Pressable
            style={styles.roundIconBtn}
            onPress={() => setSubScreen(null)}
            hitSlop={10}
          >
            <FigmaSvg name="icon_back_chevron" />
          </Pressable>
          <Text style={styles.subHeaderTitle}>Settings</Text>
        </View>

        <ScrollView
          contentContainerStyle={styles.settingsBody}
          showsVerticalScrollIndicator={false}
        >
          {/* Account Section (607:13069) */}
          <View style={styles.settingsSection}>
            <Text style={styles.settingsGroupLabel}>Account</Text>
            <View style={styles.settingsCard}>
              <Pressable
                style={styles.settingsRow}
                onPress={() => setPushEnabled((v) => !v)}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.settingsItemTitle}>Push Notifications</Text>
                  <Text style={styles.settingsItemSub}>
                    Receive updates by phone
                  </Text>
                </View>
                <View
                  style={[
                    styles.toggleTrack,
                    pushEnabled ? styles.toggleTrackOn : styles.toggleTrackOff,
                  ]}
                >
                  <View style={styles.toggleThumb} />
                </View>
              </Pressable>
              <View style={styles.cardDivider} />
              <Pressable
                style={styles.settingsRow}
                onPress={() => setEmailEnabled((v) => !v)}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.settingsItemTitle}>Email Notifications</Text>
                  <Text style={styles.settingsItemSub}>
                    Receive updates by email
                  </Text>
                </View>
                <View
                  style={[
                    styles.toggleTrack,
                    emailEnabled ? styles.toggleTrackOn : styles.toggleTrackOff,
                  ]}
                >
                  <View style={styles.toggleThumb} />
                </View>
              </Pressable>
            </View>
          </View>

          {/* Privacy & Safety Section (607:13085) */}
          <View style={styles.settingsSection}>
            <Text style={styles.settingsGroupLabel}>Privacy & Safety</Text>
            <View style={styles.settingsCard}>
              <Pressable
                style={styles.settingsRow}
                onPress={() => setPrivateAccount((v) => !v)}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.settingsItemTitle}>Private Account</Text>
                  <Text style={styles.settingsItemSub}>
                    Only approved followers see your content
                  </Text>
                </View>
                <View
                  style={[
                    styles.toggleTrack,
                    privateAccount ? styles.toggleTrackOn : styles.toggleTrackOff,
                  ]}
                >
                  <View style={styles.toggleThumb} />
                </View>
              </Pressable>
              <View style={styles.cardDivider} />
              <Pressable
                style={styles.settingsRow}
                onPress={() => setActivityStatus((v) => !v)}
              >
                <View style={{ flex: 1 }}>
                  <Text style={styles.settingsItemTitle}>Activity Status</Text>
                  <Text style={styles.settingsItemSub}>
                    {`Show when you're active`}
                  </Text>
                </View>
                <View
                  style={[
                    styles.toggleTrack,
                    activityStatus ? styles.toggleTrackOn : styles.toggleTrackOff,
                  ]}
                >
                  <View style={styles.toggleThumb} />
                </View>
              </Pressable>
              <View style={styles.cardDivider} />
              <View style={styles.settingsRow}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.settingsItemTitle}>
                    Two-Factor Authentication
                  </Text>
                  <Text style={styles.settingsItemSub}>Add extra security</Text>
                </View>
                <View style={styles.settingsChevronPill}>
                  <View style={{ transform: [{ rotate: "180deg" }] }}>
                    <FigmaSvg name="icon_back_chevron" width={12} height={12} />
                  </View>
                </View>
              </View>
            </View>
          </View>

          {/* Support Section (607:13109) */}
          <View style={styles.settingsSection}>
            <Text style={styles.settingsGroupLabel}>Support</Text>
            <View style={styles.settingsCard}>
              <View style={styles.settingsRow}>
                <Text style={[styles.settingsItemTitle, { flex: 1 }]}>
                  Help Center
                </Text>
                <View style={styles.settingsChevronPill}>
                  <View style={{ transform: [{ rotate: "180deg" }] }}>
                    <FigmaSvg name="icon_back_chevron" width={12} height={12} />
                  </View>
                </View>
              </View>
              <View style={styles.cardDivider} />
              <View style={styles.settingsRow}>
                <Text style={[styles.settingsItemTitle, { flex: 1 }]}>
                  Rate Lit Social
                </Text>
                <View style={styles.settingsChevronPill}>
                  <View style={{ transform: [{ rotate: "180deg" }] }}>
                    <FigmaSvg name="icon_back_chevron" width={12} height={12} />
                  </View>
                </View>
              </View>
            </View>
          </View>

          {/* Account Action Section (607:13123) */}
          <View style={styles.settingsSection}>
            <Text style={styles.settingsGroupLabel}>Account Action</Text>
            <View style={styles.settingsCard}>
              <Pressable style={styles.settingsRow}>
                <Text style={styles.settingsDangerText}>Delete Account</Text>
                <View style={styles.settingsDangerPill}>
                  <FigmaSvg name="settings_trash" />
                </View>
              </Pressable>
              <View style={styles.cardDivider} />
              <Pressable
                style={styles.settingsRow}
                onPress={() => {
                  setSubScreen(null);
                  signOut();
                }}
              >
                <Text style={styles.settingsDangerText}>Log Out</Text>
                <View style={styles.settingsDangerPill}>
                  <FigmaSvg name="settings_logout" />
                </View>
              </Pressable>
            </View>
          </View>

          <Text style={styles.versionFooter}>Lit Social v1.0.0</Text>
        </ScrollView>
      </View>
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════════
   * MAIN 4 TABS: HOME (283:833), DISCOVER (283:1875), EVENTS (283:2042), PROFILE (283:1044)
   * ═══════════════════════════════════════════════════════════════════════════ */

  return (
    <View style={styles.root}>
      {/* Top full-bleed blurred wave matching Figma (283:834) */}
      <GradientWave height={275} />

      {/* ── TAB 1: HOME (283:833) ── */}
      {activeTab === "home" && (
        <ScrollView
          contentContainerStyle={{ paddingTop: topPad, paddingBottom: 96 }}
          showsVerticalScrollIndicator={false}
        >
          {/* Top Bar (283:857) */}
          <View style={styles.homeTopBar}>
            <FigmaSvg name="logo_header" />
            <Pressable
              style={styles.homeNotifBtn}
              onPress={() => setActiveTab("events")}
              hitSlop={10}
            >
              <FigmaSvg name="icon_notification_top" />
            </Pressable>
          </View>

          {/* Stories Row (283:868) */}
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.storiesContainer}
          >
            {/* Your Story (283:870) */}
            <Pressable
              style={styles.yourStoryCol}
              onPress={() => setSubScreen("create-post")}
            >
              <View style={styles.yourStoryAvatarBox}>
                <Image
                  source={FIGMA_IMAGES.story_your}
                  style={styles.yourStoryImg}
                />
                <View style={styles.yourStoryPlusBadge}>
                  <FigmaSvg name="icon_plus_small" />
                </View>
              </View>
              <Text style={styles.storyLabel} numberOfLines={1}>
                Your Story
              </Text>
            </Pressable>

            {/* 4 Flame Stories (283:878..896) */}
            {FLAME_STORIES.map((st) => (
              <View key={st.id} style={styles.flameStoryCol}>
                <View style={styles.flameRingBox}>
                  <FigmaSvg name="story_flame_ring" />
                  <Image source={st.avatar} style={styles.flameStoryAvatar} />
                </View>
                <Text style={styles.storyLabel} numberOfLines={1}>
                  {st.name}
                </Text>
              </View>
            ))}
          </ScrollView>

          {/* Posts Feed (283:902) */}
          <View style={styles.postsStack}>
            {posts.map((post) => (
              <View key={post.id} style={styles.postCard}>
                {/* Post Author Row (283:907) */}
                <View style={styles.postAuthorRow}>
                  <View style={styles.postAuthorLeft}>
                    <Image
                      source={post.author.avatar}
                      style={styles.postAuthorAvatar}
                    />
                    <View style={{ gap: 4 }}>
                      <Text style={styles.postAuthorName}>
                        {post.author.name}
                      </Text>
                      <Text style={styles.postAuthorHandle}>
                        @{post.author.username} · {post.timeAgo}
                      </Text>
                    </View>
                  </View>
                  <Pressable style={styles.roundIconBtn} hitSlop={8}>
                    <View style={{ transform: [{ rotate: "90deg" }] }}>
                      <FigmaSvg name="icon_more_dots" />
                    </View>
                  </Pressable>
                </View>

                {/* Post Media Image (283:922) */}
                <View style={styles.postMediaWrap}>
                  <Image
                    source={post.image}
                    style={styles.postMediaImg}
                    resizeMode="cover"
                  />
                  {post.hasPagination && (
                    <View style={styles.postPaginationWrap}>
                      <FigmaSvg name="pagination_dots" />
                    </View>
                  )}
                </View>

                {/* Post Actions Row (283:929) */}
                <View style={styles.postActionsRow}>
                  <Pressable style={styles.postActionBtn}>
                    <FigmaSvg name="icon_heart_filled" />
                    <Text style={styles.postActionCount}>{post.likes}</Text>
                  </Pressable>
                  <Pressable style={styles.postActionBtn}>
                    <FigmaSvg name="icon_comment" />
                    <Text style={styles.postActionCount}>{post.comments}</Text>
                  </Pressable>
                  <Pressable style={styles.postActionBtn}>
                    <FigmaSvg name="icon_share_box" />
                    <Text style={styles.postActionCount}>{post.shares}</Text>
                  </Pressable>
                  <View style={{ flex: 1, alignItems: "flex-end" }}>
                    <Pressable hitSlop={8}>
                      <FigmaSvg name="icon_bookmark" />
                    </Pressable>
                  </View>
                </View>

                {/* Caption (283:947) */}
                <Text style={styles.postCaption}>{post.content}</Text>

                {/* Linked Event Card (283:948) */}
                {post.linkedEvent && (
                  <Pressable
                    style={styles.linkedEventCard}
                    onPress={() => setSubScreen("event-details")}
                  >
                    <Image
                      source={post.linkedEvent.thumb}
                      style={styles.linkedEventThumb}
                    />
                    <View style={{ flex: 1, gap: 2 }}>
                      <Text style={styles.linkedEventLabel}>
                        {post.linkedEvent.label}
                      </Text>
                      <Text style={styles.linkedEventTitle}>
                        {post.linkedEvent.title}
                      </Text>
                    </View>
                    <FigmaSvg name="icon_calendar_event" />
                  </Pressable>
                )}
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {/* ── TAB 2: DISCOVER (283:1875) ── */}
      {activeTab === "discover" && (
        <ScrollView
          contentContainerStyle={{
            paddingTop: topPad,
            paddingBottom: 96,
            paddingHorizontal: 20,
          }}
          showsVerticalScrollIndicator={false}
        >
          {/* Header + Search Bar (283:1996) */}
          <View style={styles.tabHeaderBlock}>
            <Text style={styles.tabScreenTitle}>Discover</Text>
            <View style={styles.searchPill}>
              <TextInput
                style={styles.searchInput}
                value={discoverSearch}
                onChangeText={setDiscoverSearch}
                placeholder="Search people, events, tags..."
                placeholderTextColor="rgba(255,255,255,0.4)"
              />
              <FigmaSvg name="icon_search_orange" />
            </View>
          </View>

          <View style={{ gap: 20, marginTop: 8 }}>
            {/* Trending Tags (283:1877) */}
            <View style={{ gap: 12 }}>
              <Text style={styles.sectionHeading}>Trending</Text>
              <View style={styles.trendingTagWrap}>
                {TRENDING_TAGS.map((tag) => (
                  <Pressable key={tag} style={styles.trendingTagPill}>
                    <Text style={styles.trendingTagText}>{tag}</Text>
                  </Pressable>
                ))}
              </View>
            </View>

            {/* Trending People (283:1898) */}
            <View>
              <View style={styles.sectionHeaderSpread}>
                <Text style={styles.sectionHeading}>Trending</Text>
                <Pressable onPress={() => setSubScreen("vibing")}>
                  <Text style={styles.showMoreOrange}>Show More</Text>
                </Pressable>
              </View>
              <View style={{ marginTop: 4 }}>
                {DISCOVER_USERS.map((u) => {
                  const isVibing = vibingMap[u.id] ?? u.vibing;
                  return (
                    <View key={u.id} style={styles.discoverUserRow}>
                      <Image source={u.avatar} style={styles.userListAvatar} />
                      <View style={styles.userListInfo}>
                        <Text style={styles.userListName}>{u.name}</Text>
                        <Text style={styles.userListMeta}>{u.meta}</Text>
                      </View>
                      <Pressable
                        style={[
                          styles.vibeActionPillSmall,
                          isVibing
                            ? styles.vibeActionPillActive
                            : styles.vibeActionPillIdle,
                        ]}
                        onPress={() => toggleVibe(u.id)}
                      >
                        <Text
                          style={
                            isVibing
                              ? styles.vibeActionTextActive
                              : styles.vibeActionTextIdle
                          }
                        >
                          {isVibing ? "Vibing" : "Vibe"}
                        </Text>
                      </Pressable>
                    </View>
                  );
                })}
              </View>
            </View>

            {/* Trending Events (283:1938) */}
            <View style={{ gap: 12 }}>
              <View style={styles.sectionHeaderSpread}>
                <Text style={styles.sectionHeading}>Trending</Text>
                <Pressable onPress={() => setActiveTab("events")}>
                  <Text style={styles.showMoreOrange}>Show More</Text>
                </Pressable>
              </View>
              <View style={{ gap: 12 }}>
                {TRENDING_EVENTS.map((ev) => (
                  <Pressable
                    key={ev.id}
                    style={styles.discoverEventCard}
                    onPress={() => setSubScreen("event-details")}
                  >
                    <Image
                      source={FIGMA_IMAGES.event_thumb}
                      style={styles.discoverEventThumb}
                    />
                    <View style={{ flex: 1, gap: 2 }}>
                      <Text style={styles.discoverEventVenue}>{ev.venue}</Text>
                      <Text style={styles.discoverEventTitle}>{ev.title}</Text>
                      <Text style={styles.discoverEventVenue}>{ev.meta}</Text>
                    </View>
                  </Pressable>
                ))}
              </View>
            </View>
          </View>
        </ScrollView>
      )}

      {/* ── TAB 3: EVENTS (283:2042) ── */}
      {activeTab === "events" && (
        <ScrollView
          contentContainerStyle={{ paddingTop: topPad, paddingBottom: 96 }}
          showsVerticalScrollIndicator={false}
        >
          <View style={[styles.tabHeaderBlock, { paddingHorizontal: 20 }]}>
            <Text style={styles.tabScreenTitle}>Events</Text>
            <View style={styles.searchPill}>
              <TextInput
                style={styles.searchInput}
                value={eventsSearch}
                onChangeText={setEventsSearch}
                placeholder="Search events, venues..."
                placeholderTextColor="rgba(255,255,255,0.4)"
              />
              <FigmaSvg name="icon_search_orange" />
            </View>
          </View>

          <View style={{ gap: 12, marginTop: 8 }}>
            {[1, 2].map((idx) => (
              <Pressable
                key={idx}
                style={styles.eventFeedCard}
                onPress={() => setSubScreen("event-details")}
              >
                <View style={styles.postAuthorLeft}>
                  <Image
                    source={FIGMA_IMAGES.avatar_maya}
                    style={styles.postAuthorAvatar}
                  />
                  <View style={{ gap: 4 }}>
                    <Text style={styles.postAuthorName}>Maya Chen</Text>
                    <Text style={styles.postAuthorHandle}>
                      @maya_vibes · 2h ago
                    </Text>
                  </View>
                </View>

                <View style={styles.eventFeedBannerWrap}>
                  <Image
                    source={FIGMA_IMAGES.post_1}
                    style={styles.eventFeedBannerImg}
                    resizeMode="cover"
                  />
                  <View style={styles.eventBannerDots}>
                    <FigmaSvg name="pagination_dots" />
                  </View>
                </View>

                <View style={styles.eventFeedInfoBlock}>
                  <View style={{ gap: 4 }}>
                    <Text style={styles.ticketEventTitle}>
                      Sunset Groove: A Summer Festival
                    </Text>
                    <View style={styles.eventMetaInlineRow}>
                      <View style={styles.eventMetaItem}>
                        <FigmaSvg name="icon_pin_small" />
                        <Text style={styles.eventMetaText}>Warehouse 23</Text>
                      </View>
                      <View style={styles.eventMetaItem}>
                        <FigmaSvg name="icon_clock_small" />
                        <Text style={styles.eventMetaText}>10:00 PM</Text>
                      </View>
                    </View>
                  </View>

                  <View style={styles.goingRow}>
                    <View style={styles.attendeeStack}>
                      <Image
                        source={FIGMA_IMAGES.attendee_1}
                        style={[styles.attendeeAvatar, { marginLeft: 0 }]}
                      />
                      <Image
                        source={FIGMA_IMAGES.attendee_2}
                        style={styles.attendeeAvatar}
                      />
                      <Image
                        source={FIGMA_IMAGES.attendee_3}
                        style={styles.attendeeAvatar}
                      />
                    </View>
                    <Text style={styles.goingCountWhite}>342 going</Text>
                  </View>
                </View>

                <View style={styles.eventCardFooter}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.priceBigText}>$60</Text>
                    <Text style={styles.priceSubLabel}>Price</Text>
                  </View>
                  <Pressable
                    style={styles.smallOrangePillBtn}
                    onPress={() => setSubScreen("select-ticket")}
                  >
                    <Text style={styles.smallOrangePillText}>
                      Purchas & RSVP
                    </Text>
                  </Pressable>
                </View>
              </Pressable>
            ))}
          </View>
        </ScrollView>
      )}

      {/* ── TAB 4: PROFILE (283:1044) ── */}
      {activeTab === "profile" && (
        <ScrollView
          contentContainerStyle={{ paddingTop: topPad, paddingBottom: 96 }}
          showsVerticalScrollIndicator={false}
        >
          {/* Top Bar (283:1068) */}
          <View style={styles.profileTopBar}>
            <Text style={styles.tabScreenTitle}>Profile</Text>
            <Pressable
              style={styles.roundIconBtn}
              onPress={() => setProfileMenuOpen(true)}
              hitSlop={10}
            >
              <View style={{ transform: [{ rotate: "90deg" }] }}>
                <FigmaSvg name="icon_more_dots" />
              </View>
            </Pressable>
          </View>

          <View style={styles.profileStatsContainer}>
            {/* Avatar + Stats (283:1116) */}
            <View style={styles.profileHeaderStatsRow}>
              <View style={styles.profileAvatarRingBox}>
                <FigmaSvg name="profile_ring" width={84} height={84} />
                <Image
                  source={FIGMA_IMAGES.profile_athik}
                  style={styles.profileMainAvatar}
                />
              </View>
              <View style={styles.profileCountsRow}>
                <View style={styles.profileCountItem}>
                  <Text style={styles.profileCountNumber}>5</Text>
                  <Text style={styles.profileCountLabel}>Posts</Text>
                </View>
                <Pressable
                  style={styles.profileCountItem}
                  onPress={() => {
                    setVibingTab("viber");
                    setSubScreen("vibing");
                  }}
                >
                  <Text style={styles.profileCountNumber}>2.8k</Text>
                  <Text style={styles.profileCountLabel}>Vibers</Text>
                </Pressable>
                <Pressable
                  style={styles.profileCountItem}
                  onPress={() => {
                    setVibingTab("vibing");
                    setSubScreen("vibing");
                  }}
                >
                  <Text style={styles.profileCountNumber}>412</Text>
                  <Text style={styles.profileCountLabel}>Vibing</Text>
                </Pressable>
              </View>
            </View>

            {/* Name, Bio, Social Links (283:1131) */}
            <View style={{ gap: 16, width: "100%" }}>
              <View style={{ gap: 4 }}>
                <Text style={styles.profileDisplayName}>
                  {session?.profile?.display_name || "Md. Athik Foisal"}
                </Text>
                <Text style={styles.profileHandleText}>
                  @{session?.profile?.username || "athik_foisal"}
                </Text>
              </View>

              <View style={{ gap: 12 }}>
                <Text style={styles.profileBioText}>
                  {session?.profile?.bio ||
                    "🔥 Living for the moment. Events curator & nightlife enthusiast. NYC 🗽"}
                </Text>
                <View style={styles.cardDivider} />
                <View style={styles.profileLinksRow}>
                  <View style={styles.profileLinkItem}>
                    <FigmaSvg name="icon_facebook" />
                    <Text style={styles.profileLinkText} numberOfLines={1}>
                      @athik_foisal
                    </Text>
                  </View>
                  <View style={styles.profileLinkItem}>
                    <FigmaSvg name="icon_instagram" />
                    <Text style={styles.profileLinkText} numberOfLines={1}>
                      @athik_foisal
                    </Text>
                  </View>
                  <View style={styles.profileLinkItem}>
                    <FigmaSvg name="icon_globe" />
                    <Text style={styles.profileLinkText} numberOfLines={1}>
                      athikui.com
                    </Text>
                  </View>
                </View>
              </View>
            </View>
          </View>

          {/* Posts / Events Tabs (283:1170) */}
          <View style={[styles.twoTabRow, { marginTop: 20 }]}>
            <Pressable
              style={[
                styles.twoTabItem,
                profileTab === "posts"
                  ? styles.twoTabItemActive
                  : styles.twoTabItemInactive,
              ]}
              onPress={() => setProfileTab("posts")}
            >
              <Text
                style={
                  profileTab === "posts"
                    ? styles.twoTabTextActive
                    : styles.twoTabTextInactive
                }
              >
                Posts
              </Text>
            </Pressable>
            <Pressable
              style={[
                styles.twoTabItem,
                profileTab === "events"
                  ? styles.twoTabItemActive
                  : styles.twoTabItemInactive,
              ]}
              onPress={() => setProfileTab("events")}
            >
              <Text
                style={
                  profileTab === "events"
                    ? styles.twoTabTextActive
                    : styles.twoTabTextInactive
                }
              >
                Events
              </Text>
            </Pressable>
          </View>

          {/* 3x3 Gallery (283:1175) */}
          <View style={styles.profileGalleryBox}>
            {GALLERY_ROWS.map((row, rIdx) => (
              <View key={rIdx} style={styles.profileGalleryRow}>
                {row.map((imgSource, cIdx) => (
                  <Image
                    key={cIdx}
                    source={imgSource}
                    style={styles.profileGalleryImg}
                    resizeMode="cover"
                  />
                ))}
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {/* ── BOTTOM NAVIGATION BAR (283:1005) ── */}
      <View
        style={[
          styles.bottomNavContainer,
          { paddingBottom: Math.max(insets.bottom, 10) },
        ]}
      >
        <View style={styles.bottomNavInner}>
          {/* Home */}
          <Pressable
            style={styles.bottomNavTab}
            onPress={() => setActiveTab("home")}
          >
            {activeTab === "home" && (
              <Image
                source={FIGMA_IMAGES.nav_active_glow}
                style={styles.navActiveSpotlight}
                resizeMode="stretch"
              />
            )}
            <FigmaSvg
              name={
                activeTab === "home" ? "nav_home_active" : "nav_home_inactive"
              }
            />
            <Text
              style={[
                styles.bottomNavLabel,
                activeTab === "home" && styles.bottomNavLabelActive,
              ]}
            >
              Home
            </Text>
          </Pressable>

          {/* Discover */}
          <Pressable
            style={styles.bottomNavTab}
            onPress={() => setActiveTab("discover")}
          >
            {activeTab === "discover" && (
              <Image
                source={FIGMA_IMAGES.nav_active_glow}
                style={styles.navActiveSpotlight}
                resizeMode="stretch"
              />
            )}
            <FigmaSvg
              name={
                activeTab === "discover"
                  ? "nav_discover_active"
                  : "nav_discover_inactive"
              }
            />
            <Text
              style={[
                styles.bottomNavLabel,
                activeTab === "discover" && styles.bottomNavLabelActive,
              ]}
            >
              Discover
            </Text>
          </Pressable>

          {/* Center Create (+) Button (283:1022) */}
          <Pressable
            style={styles.bottomNavPlusBtn}
            onPress={() => setSubScreen("create-post")}
          >
            <Svg
              width={36}
              height={36}
              viewBox="0 0 36 36"
              style={StyleSheet.absoluteFill}
            >
              <Defs>
                <SvgLinearGradient
                  id="navPlusBase"
                  x1="4"
                  y1="32"
                  x2="32"
                  y2="4"
                  gradientUnits="userSpaceOnUse"
                >
                  <Stop offset="0%" stopColor="#F5A623" />
                  <Stop offset="45%" stopColor="#F06A18" />
                  <Stop offset="100%" stopColor="#ED4113" />
                </SvgLinearGradient>
                <SvgRadialGradient
                  id="navPlusWarmGlow"
                  cx="8"
                  cy="28"
                  r="22"
                  gradientUnits="userSpaceOnUse"
                >
                  <Stop offset="0%" stopColor="#FFB838" stopOpacity="0.85" />
                  <Stop offset="55%" stopColor="#F09B1E" stopOpacity="0.25" />
                  <Stop offset="100%" stopColor="#ED4113" stopOpacity="0" />
                </SvgRadialGradient>
              </Defs>
              <Circle cx="18" cy="18" r="17.5" fill="url(#navPlusBase)" />
              <Circle
                cx="18"
                cy="18"
                r="17.5"
                fill="url(#navPlusWarmGlow)"
                stroke="#F09B1E"
                strokeWidth="1"
              />
            </Svg>
            <FigmaSvg name="nav_plus_icon" width={16} height={16} />
          </Pressable>

          {/* Events */}
          <Pressable
            style={styles.bottomNavTab}
            onPress={() => setActiveTab("events")}
          >
            {activeTab === "events" && (
              <Image
                source={FIGMA_IMAGES.nav_active_glow}
                style={styles.navActiveSpotlight}
                resizeMode="stretch"
              />
            )}
            <FigmaSvg
              name={
                activeTab === "events"
                  ? "nav_events_active"
                  : "nav_events_inactive"
              }
            />
            <Text
              style={[
                styles.bottomNavLabel,
                activeTab === "events" && styles.bottomNavLabelActive,
              ]}
            >
              Events
            </Text>
          </Pressable>

          {/* Profile */}
          <Pressable
            style={styles.bottomNavTab}
            onPress={() => setActiveTab("profile")}
          >
            {activeTab === "profile" && (
              <Image
                source={FIGMA_IMAGES.nav_active_glow}
                style={styles.navActiveSpotlight}
                resizeMode="stretch"
              />
            )}
            <FigmaSvg
              name={
                activeTab === "profile"
                  ? "nav_profile_active"
                  : "nav_profile_inactive"
              }
            />
            <Text
              style={[
                styles.bottomNavLabel,
                activeTab === "profile" && styles.bottomNavLabelActive,
              ]}
            >
              Profile
            </Text>
          </Pressable>
        </View>
      </View>

      {/* ── PROFILE MENU BOTTOM SHEET (283:1188) ── */}
      {profileMenuOpen && (
        <View style={styles.sheetBackdrop}>
          <Pressable
            style={{ flex: 1, width: "100%" }}
            onPress={() => setProfileMenuOpen(false)}
          />
          <View style={styles.profileMenuSheet}>
            <View style={styles.profileMenuHeader}>
              <View style={styles.profileMenuUserRow}>
                <Image
                  source={FIGMA_IMAGES.profile_jayden}
                  style={styles.userListAvatar}
                />
                <View>
                  <Text style={styles.userListName}>{editFullName}</Text>
                  <Text style={styles.profileMenuHandle}>{editUsername}</Text>
                </View>
              </View>
              <Pressable
                style={styles.profileMenuCloseBtn}
                onPress={() => setProfileMenuOpen(false)}
              >
                <FigmaSvg name="icon_close" width={16} height={16} />
              </Pressable>
            </View>

            <Pressable
              style={styles.profileMenuItem}
              onPress={() => {
                setProfileMenuOpen(false);
                setSubScreen("edit-profile");
              }}
            >
              <FigmaSvg name="menu_edit_profile" />
              <Text style={styles.profileMenuItemText}>Edit Profile</Text>
            </Pressable>

            <Pressable
              style={styles.profileMenuItem}
              onPress={() => setProfileMenuOpen(false)}
            >
              <FigmaSvg name="menu_share_profile" />
              <Text style={styles.profileMenuItemText}>Share Profile</Text>
            </Pressable>

            <Pressable
              style={styles.profileMenuItem}
              onPress={() => setProfileMenuOpen(false)}
            >
              <FigmaSvg name="menu_copy_link" />
              <Text style={styles.profileMenuItemText}>Copy Profile Link</Text>
            </Pressable>

            <Pressable
              style={styles.profileMenuItem}
              onPress={() => {
                setProfileMenuOpen(false);
                setSubScreen("settings");
              }}
            >
              <FigmaSvg name="menu_settings" />
              <Text style={styles.profileMenuItemText}>Settings</Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#07070E",
  },

  /* Home Top Bar (283:857) */
  homeTopBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingTop: 4,
    paddingBottom: 8,
  },
  homeNotifBtn: {
    width: 40,
    height: 40,
    borderRadius: 88,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  roundIconBtn: {
    width: 36,
    height: 36,
    borderRadius: 88,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },

  /* Stories Row (283:868) */
  storiesContainer: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    gap: 16,
    alignItems: "flex-end",
  },
  yourStoryCol: {
    width: 65,
    alignItems: "center",
    gap: 4,
  },
  yourStoryAvatarBox: {
    width: 56,
    height: 56,
    position: "relative",
  },
  yourStoryImg: {
    width: 56,
    height: 56,
    borderRadius: 28,
  },
  yourStoryPlusBadge: {
    position: "absolute",
    right: 0,
    bottom: 0,
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: "#ED4113",
    borderWidth: 1.05,
    borderColor: "#07070E",
    alignItems: "center",
    justifyContent: "center",
  },
  flameStoryCol: {
    width: 52,
    alignItems: "center",
    gap: 4,
  },
  flameRingBox: {
    width: 51.974,
    height: 58.795,
    position: "relative",
  },
  flameStoryAvatar: {
    position: "absolute",
    left: 4.39,
    top: 18.02,
    width: 41.16,
    height: 41.976,
    borderRadius: 21,
  },
  storyLabel: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    lineHeight: 16.8,
    textAlign: "center",
  },

  /* Posts Feed (283:902) */
  postsStack: {
    gap: 12,
  },
  postCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    paddingHorizontal: 20,
    paddingVertical: 16,
    gap: 12,
  },
  postAuthorRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
  },
  postAuthorLeft: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  postAuthorAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
  },
  postAuthorName: {
    color: "#F2F2F8",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 15.4,
  },
  postAuthorHandle: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
    lineHeight: 16,
  },
  postMediaWrap: {
    width: "100%",
    height: 292,
    borderRadius: 20,
    overflow: "hidden",
    position: "relative",
  },
  postMediaImg: {
    width: "100%",
    height: "100%",
    borderRadius: 20,
  },
  postPaginationWrap: {
    position: "absolute",
    bottom: 12,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  postActionsRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingTop: 12,
    paddingBottom: 13,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
  },
  postActionBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  postActionCount: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    fontWeight: "500",
  },
  postCaption: {
    color: "rgba(255,255,255,0.9)",
    fontSize: 14,
    lineHeight: 16.8,
  },
  linkedEventCard: {
    backgroundColor: "rgba(255,255,255,0.05)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 16,
    padding: 9,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  linkedEventThumb: {
    width: 40,
    height: 40,
    borderRadius: 8,
  },
  linkedEventLabel: {
    color: "rgba(255,255,255,0.7)",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 16.8,
  },
  linkedEventTitle: {
    color: "rgba(255,255,255,0.9)",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 16.8,
  },

  /* Discover & Events Header (283:1996) */
  tabHeaderBlock: {
    paddingTop: 4,
    paddingBottom: 12,
    gap: 12,
  },
  tabScreenTitle: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "600",
    lineHeight: 19.8,
  },
  searchPill: {
    height: 45,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
  },
  searchInput: {
    flex: 1,
    color: "#FFFFFF",
    fontSize: 14,
    padding: 0,
    ...(Platform.OS === "web" ? ({ outlineStyle: "none" } as any) : {}),
  },
  sectionHeading: {
    color: "#F2F2F8",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 16.8,
  },
  sectionHeaderSpread: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  showMoreOrange: {
    color: "#ED4113",
    fontSize: 14,
    fontWeight: "500",
  },
  trendingTagWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
  },
  trendingTagPill: {
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  trendingTagText: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
  },
  discoverUserRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingVertical: 12,
  },
  userListRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  userListAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  userListInfo: {
    flex: 1,
    gap: 4,
  },
  userListName: {
    color: "#F2F2F8",
    fontSize: 14,
    lineHeight: 15.4,
  },
  userListMeta: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
    lineHeight: 13.2,
  },
  vibeActionPillSmall: {
    borderRadius: 88,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
  },
  vibeActionPill: {
    borderRadius: 88,
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
  },
  vibeActionPillActive: {
    borderBottomColor: "#ED4113",
  },
  vibeActionPillIdle: {
    borderBottomColor: "rgba(255,255,255,0.1)",
  },
  vibeActionTextActive: {
    color: "#ED4113",
    fontSize: 12,
    lineHeight: 16,
  },
  vibeActionTextIdle: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
  },
  discoverEventCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 16,
    padding: 9,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  discoverEventThumb: {
    width: 54,
    height: 54,
    borderRadius: 8,
  },
  discoverEventVenue: {
    color: "rgba(255,255,255,0.7)",
    fontSize: 14,
    lineHeight: 16.8,
  },
  discoverEventTitle: {
    color: "rgba(255,255,255,0.9)",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 16.8,
  },

  /* Events Tab (283:2044) */
  eventFeedCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    paddingHorizontal: 20,
    paddingVertical: 16,
    gap: 12,
  },
  eventFeedBannerWrap: {
    width: "100%",
    height: 220,
    borderRadius: 20,
    overflow: "hidden",
    position: "relative",
  },
  eventFeedBannerImg: {
    width: "100%",
    height: "100%",
    borderRadius: 20,
  },
  eventBannerDots: {
    position: "absolute",
    bottom: 8,
    left: 0,
    right: 0,
    alignItems: "center",
  },
  eventFeedInfoBlock: {
    gap: 8,
    paddingTop: 4,
    paddingBottom: 13,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
  },
  ticketEventTitle: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    lineHeight: 19.2,
  },
  eventMetaInlineRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  eventMetaItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  eventMetaText: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
    lineHeight: 13.2,
  },
  goingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  attendeeStack: {
    flexDirection: "row",
    alignItems: "center",
  },
  attendeeAvatar: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#0E0E1C",
    marginLeft: -8,
  },
  goingCountWhite: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
  },
  goingCountMuted: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
    lineHeight: 16,
  },
  eventCardFooter: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
  },
  priceBigText: {
    color: "#FFFFFF",
    fontSize: 18,
    fontWeight: "600",
    lineHeight: 21.6,
  },
  priceSubLabel: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
    lineHeight: 13.2,
  },
  smallOrangePillBtn: {
    backgroundColor: "#ED4113",
    borderRadius: 88,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  smallOrangePillText: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "500",
  },

  /* Profile Tab (283:1044) */
  profileTopBar: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingVertical: 4,
  },
  profileStatsContainer: {
    paddingHorizontal: 20,
    marginTop: 16,
    gap: 12,
  },
  profileHeaderStatsRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 40,
  },
  profileAvatarRingBox: {
    width: 84,
    height: 84,
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  },
  profileMainAvatar: {
    position: "absolute",
    width: 80,
    height: 80,
    borderRadius: 40,
  },
  profileCountsRow: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  profileCountItem: {
    gap: 4,
  },
  profileCountNumber: {
    color: "#F2F2F8",
    fontSize: 16,
    fontWeight: "500",
    lineHeight: 17.6,
  },
  profileCountLabel: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    lineHeight: 15.4,
  },
  profileDisplayName: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "500",
    lineHeight: 16.8,
  },
  profileHandleText: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 12,
    lineHeight: 13.2,
  },
  profileBioText: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
    lineHeight: 16.8,
  },
  profileLinksRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 20,
  },
  profileLinkItem: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
  },
  profileLinkText: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
    flex: 1,
  },
  twoTabRow: {
    flexDirection: "row",
    width: "100%",
  },
  twoTabItem: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    paddingTop: 12,
    paddingBottom: 12.75,
    borderBottomWidth: 1.5,
  },
  twoTabItemActive: {
    borderBottomColor: "#ED4113",
  },
  twoTabItemInactive: {
    borderBottomColor: "rgba(255,255,255,0.1)",
  },
  twoTabTextActive: {
    color: "#ED4113",
    fontSize: 16,
    fontWeight: "500",
  },
  twoTabTextInactive: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 16,
    fontWeight: "400",
  },
  profileGalleryBox: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.05)",
    paddingHorizontal: 20,
    paddingVertical: 16,
    gap: 8,
  },
  profileGalleryRow: {
    flexDirection: "row",
    gap: 8,
  },
  profileGalleryImg: {
    flex: 1,
    height: 100,
    borderRadius: 12,
  },

  /* Bottom Navigation (283:1005) */
  bottomNavContainer: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    minHeight: 74,
    backgroundColor: "#07070E",
    borderTopWidth: 1,
    borderTopColor: "rgba(255,255,255,0.05)",
    paddingTop: 12,
    paddingHorizontal: 20,
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: -8 },
    shadowOpacity: 0.8,
    shadowRadius: 16,
    elevation: 16,
  },
  bottomNavInner: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 20,
  },
  bottomNavTab: {
    flex: 1,
    alignItems: "center",
    gap: 4,
    position: "relative",
  },
  navActiveSpotlight: {
    position: "absolute",
    top: -12,
    width: 88,
    height: 74,
    pointerEvents: "none",
  },
  bottomNavLabel: {
    color: "#FFFFFF",
    fontSize: 10,
    lineHeight: 14,
    fontWeight: "400",
  },
  bottomNavLabelActive: {
    fontWeight: "500",
  },
  bottomNavPlusBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    overflow: "hidden",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  },

  /* Profile Menu Bottom Sheet (283:1188) */
  sheetBackdrop: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: "rgba(255,255,255,0.4)",
    justifyContent: "flex-end",
  },
  profileMenuSheet: {
    backgroundColor: "#07070E",
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 28,
  },
  profileMenuHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingBottom: 13,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.05)",
  },
  profileMenuUserRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  profileMenuHandle: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
  },
  profileMenuCloseBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  profileMenuItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingVertical: 12,
  },
  profileMenuItemText: {
    color: "#F2F2F8",
    fontSize: 14,
    lineHeight: 20,
  },

  /* Sub-screens common */
  subHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 20,
    paddingVertical: 4,
  },
  subHeaderTitle: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    flex: 1,
  },
  primaryFullBtn: {
    backgroundColor: "#ED4113",
    borderRadius: 88,
    padding: 12,
    height: 44,
    alignItems: "center",
    justifyContent: "center",
    width: "100%",
  },
  primaryFullBtnText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
  },
  secondaryFullBtn: {
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    padding: 12,
    height: 45,
    alignItems: "center",
    justifyContent: "center",
    width: "100%",
  },
  secondaryFullBtnText: {
    color: "rgba(255,255,255,0.9)",
    fontSize: 16,
    fontWeight: "500",
  },

  /* Create Post (607:12031) */
  createPostBody: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 36,
    gap: 20,
  },
  createPostTagRow: {
    flexDirection: "row",
    gap: 8,
  },
  createPostTagBtn: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 4,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderRadius: 88,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  createPostTagText: {
    color: "#FFFFFF",
    fontSize: 12,
    lineHeight: 16,
  },
  createPostInput: {
    color: "#F2F2F8",
    fontSize: 14,
    lineHeight: 20,
    minHeight: 28,
    ...(Platform.OS === "web" ? ({ outlineStyle: "none" } as any) : {}),
  },
  mediaUploadBox: {
    width: "100%",
    height: 440,
    borderRadius: 16,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
  },
  mediaUploadPreview: {
    width: "100%",
    height: "100%",
  },
  mediaUploadInner: {
    alignItems: "center",
    gap: 8,
  },
  mediaUploadLabel: {
    color: "#F2F2F8",
    fontSize: 14,
    lineHeight: 20,
  },

  /* Edit Profile (283:1560) */
  editProfileScroll: {
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 36,
    alignItems: "center",
  },
  editAvatarWrap: {
    width: 124,
    height: 124,
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
    marginBottom: 20,
  },
  editAvatarImg: {
    position: "absolute",
    width: 120,
    height: 120,
    borderRadius: 60,
  },
  editCameraBadge: {
    position: "absolute",
    right: 4,
    bottom: 4,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: "#ED4113",
    borderWidth: 1,
    borderColor: "#07070E",
    alignItems: "center",
    justifyContent: "center",
  },
  editFormStack: {
    width: "100%",
    gap: 16,
  },
  editFieldGroup: {
    width: "100%",
    gap: 8,
  },
  editFieldLabel: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 14,
    paddingHorizontal: 12,
  },
  editPillInputWrap: {
    height: 45,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 16,
    justifyContent: "center",
  },
  editPillInput: {
    color: "#FFFFFF",
    fontSize: 14,
    padding: 0,
    ...(Platform.OS === "web" ? ({ outlineStyle: "none" } as any) : {}),
  },
  editBioInputWrap: {
    height: 121,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  editBioInput: {
    color: "#FFFFFF",
    fontSize: 14,
    lineHeight: 20,
    padding: 0,
    ...(Platform.OS === "web" ? ({ outlineStyle: "none" } as any) : {}),
  },
  editSocialInputWrap: {
    height: 45,
    backgroundColor: "rgba(255,255,255,0.05)",
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
    borderRadius: 88,
    paddingHorizontal: 16,
    justifyContent: "center",
    position: "relative",
  },
  editSocialAddBtn: {
    position: "absolute",
    right: 6,
    height: 32,
    backgroundColor: "#ED4113",
    borderRadius: 88,
    paddingHorizontal: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  editSocialAddText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
  },
  editSocialChipRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingLeft: 12,
    marginTop: 4,
  },
  editSocialChipText: {
    color: "#FFFFFF",
    fontSize: 12,
  },

  /* Vibing / Viber (283:1655) */
  vibingHeaderRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 20,
    paddingVertical: 4,
  },
  vibingHeaderTitle: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    flex: 1,
  },
  vibingAddUserBtn: {
    width: 36,
    height: 36,
    borderRadius: 88,
    backgroundColor: "#ED4113",
    alignItems: "center",
    justifyContent: "center",
  },
  vibingListScroll: {
    paddingTop: 8,
    paddingBottom: 32,
  },

  /* Event Details (283:2207) */
  eventDetailsHero: {
    width: "100%",
    height: 220,
    position: "relative",
  },
  eventDetailsHeroImg: {
    width: "100%",
    height: "100%",
  },
  eventDetailsHeroOverlay: {
    position: "absolute",
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: "rgba(7,7,14,0.35)",
  },
  eventDetailsTopBar: {
    position: "absolute",
    left: 0,
    right: 0,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 20,
  },
  darkGlassIconBtn: {
    width: 36,
    height: 36,
    borderRadius: 88,
    backgroundColor: "rgba(7,7,14,0.45)",
    alignItems: "center",
    justifyContent: "center",
  },
  eventDetailsBody: {
    paddingHorizontal: 20,
    paddingTop: 12,
    gap: 16,
  },
  eventDetailsTitle: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    lineHeight: 19.2,
  },
  eventDetailsMetaRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  ratingRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  ratingBadge: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
    backgroundColor: "rgba(255,185,0,0.1)",
    borderWidth: 1,
    borderColor: "rgba(255,185,0,0.2)",
    borderRadius: 999,
    paddingHorizontal: 9,
    height: 24,
  },
  ratingBadgeText: {
    color: "#FFB900",
    fontSize: 12,
  },
  ratingCountText: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 14,
  },
  eventInfoCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 20,
    padding: 12,
    gap: 12,
  },
  eventInfoItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  eventInfoIconCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: "rgba(255,255,255,0.1)",
    alignItems: "center",
    justifyContent: "center",
  },
  eventInfoTextCol: {
    gap: 2,
  },
  eventInfoLabel: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 12,
  },
  eventInfoValue: {
    color: "#F2F2F8",
    fontSize: 14,
  },
  cardDivider: {
    width: "100%",
    height: 1,
    backgroundColor: "rgba(255,255,255,0.08)",
  },
  progressTrack: {
    width: "100%",
    height: 6,
    borderRadius: 999,
    backgroundColor: "rgba(255,255,255,0.1)",
    marginTop: 6,
    overflow: "hidden",
  },
  progressFill: {
    width: "68%",
    height: 6,
    borderRadius: 999,
    backgroundColor: "#ED4113",
  },
  aboutParagraph: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 14,
    lineHeight: 18,
  },
  showMoreSmall: {
    color: "#ED4113",
    fontSize: 12,
    fontWeight: "500",
  },
  scheduleCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 20,
    padding: 12,
    flexDirection: "row",
    gap: 12,
  },
  scheduleCol: {
    flex: 1,
    gap: 8,
  },
  scheduleVerticalDivider: {
    width: 1,
    backgroundColor: "rgba(255,255,255,0.08)",
  },
  scheduleRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  scheduleTime: {
    color: "rgba(255,255,255,0.6)",
    fontSize: 10,
  },
  scheduleLabel: {
    color: "#F2F2F8",
    fontSize: 12,
  },
  locationCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 20,
    overflow: "hidden",
    paddingBottom: 12,
    gap: 10,
  },
  locationMapWrap: {
    width: "100%",
    height: 160,
    position: "relative",
  },
  locationMapImg: {
    width: "100%",
    height: "100%",
  },
  locationPinOverlay: {
    position: "absolute",
    left: 91,
    top: 54,
  },
  locationFooterRow: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    gap: 10,
  },
  locationVenueSmall: {
    color: "#F2F2F8",
    fontSize: 12,
  },
  locationCityText: {
    color: "#F2F2F8",
    fontSize: 14,
  },
  hostCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 16,
    padding: 13,
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
  },
  fromEventThumb: {
    width: 100,
    height: 100,
    borderRadius: 16,
  },
  stickyBottomBar: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: "#07070E",
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 24,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    borderTopWidth: 1,
    borderTopColor: "rgba(255,255,255,0.05)",
  },

  /* Tickets & Order Summary (283:2371 / 283:2469 / 283:2624) */
  ticketContentWrap: {
    paddingHorizontal: 20,
    paddingTop: 16,
    gap: 20,
  },
  ticketEventSummary: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: "rgba(255,255,255,0.1)",
  },
  ticketEventThumb: {
    width: 66,
    height: 66,
    borderRadius: 8,
  },
  ticketTierCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 16,
    padding: 12,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  ticketTierName: {
    color: "#F2F2F8",
    fontSize: 14,
  },
  ticketTierPrice: {
    color: "#ED4113",
    fontSize: 16,
    fontWeight: "500",
  },
  qtyStepperRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  qtyValueText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "500",
    width: 20,
    textAlign: "center",
  },
  stickyBottomColumnBar: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: "#07070E",
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 24,
    gap: 12,
    borderTopWidth: 1,
    borderTopColor: "rgba(255,255,255,0.05)",
  },
  totalRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  orderBreakdownCard: {
    backgroundColor: "rgba(255,255,255,0.02)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.05)",
    borderRadius: 20,
    padding: 16,
    gap: 12,
  },
  orderItemRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  orderPriceText: {
    color: "rgba(255,255,255,0.8)",
    fontSize: 14,
  },
  stripeCard: {
    backgroundColor: "rgba(244,63,94,0.05)",
    borderWidth: 1,
    borderColor: "#ED4113",
    borderRadius: 16,
    padding: 12,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  securePaymentRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    marginTop: 8,
  },
  qrCodeContainer: {
    width: 335,
    height: 335,
    alignSelf: "center",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  },
  qrCenterBadgeWrap: {
    position: "absolute",
  },

  /* Settings (607:13040) */
  settingsBody: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 40,
    gap: 20,
  },
  settingsSection: {
    gap: 4,
  },
  settingsGroupLabel: {
    color: "#F2F2F8",
    fontSize: 12,
    lineHeight: 20,
  },
  settingsCard: {
    backgroundColor: "rgba(255,255,255,0.05)",
    borderRadius: 16,
    padding: 12,
    gap: 8,
  },
  settingsRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 12,
  },
  settingsItemTitle: {
    color: "#F2F2F8",
    fontSize: 14,
    lineHeight: 20,
  },
  settingsItemSub: {
    color: "rgba(242,242,248,0.6)",
    fontSize: 12,
    lineHeight: 16,
  },
  toggleTrack: {
    width: 32,
    height: 20,
    borderRadius: 9999,
    padding: 4,
    justifyContent: "center",
  },
  toggleTrackOn: {
    backgroundColor: "#ED4113",
    alignItems: "flex-end",
  },
  toggleTrackOff: {
    backgroundColor: "#07070E",
    alignItems: "flex-start",
  },
  toggleThumb: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "#FFFFFF",
  },
  settingsChevronPill: {
    width: 24,
    height: 24,
    borderRadius: 88,
    backgroundColor: "rgba(255,255,255,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  settingsDangerText: {
    color: "#EF4444",
    fontSize: 14,
    lineHeight: 20,
    flex: 1,
  },
  settingsDangerPill: {
    width: 24,
    height: 24,
    borderRadius: 88,
    backgroundColor: "rgba(239,68,68,0.05)",
    alignItems: "center",
    justifyContent: "center",
  },
  versionFooter: {
    color: "#F2F2F8",
    fontSize: 12,
    textAlign: "center",
    marginTop: 24,
  },
});
